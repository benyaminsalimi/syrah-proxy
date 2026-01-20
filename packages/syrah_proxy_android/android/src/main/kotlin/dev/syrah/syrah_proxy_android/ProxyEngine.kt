package dev.syrah.syrah_proxy_android

import android.content.Context
import java.io.BufferedReader
import java.io.BufferedWriter
import java.io.InputStreamReader
import java.io.OutputStreamWriter
import java.net.InetSocketAddress
import java.net.ServerSocket
import java.net.Socket
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.atomic.AtomicLong
import javax.net.ssl.SSLContext
import javax.net.ssl.SSLSocket
import javax.net.ssl.SSLSocketFactory

/**
 * Proxy engine for intercepting HTTP/HTTPS traffic on Android
 */
class ProxyEngine(
    private val context: Context,
    private val certificateAuthority: CertificateAuthority
) {
    interface ProxyListener {
        fun onFlowCaptured(flow: Map<String, Any>)
        fun onStatusChanged(status: Map<String, Any>)
        fun onError(error: String)
    }

    private var listener: ProxyListener? = null
    private var serverSocket: ServerSocket? = null
    private var executorService: ExecutorService? = null

    private val isRunning = AtomicBoolean(false)
    private var port: Int = 8888
    private var sslInterceptionEnabled: Boolean = true
    private var bypassApps: List<String> = emptyList()

    private val activeConnections = AtomicInteger(0)
    private val bytesReceived = AtomicLong(0)
    private val bytesSent = AtomicLong(0)
    private val flowCounter = AtomicInteger(0)

    private val flows = ConcurrentHashMap<String, ProxyFlow>()
    private var rules: List<Map<String, Any>> = emptyList()

    // Throttling settings
    private var throttleDownload: Int = 0
    private var throttleUpload: Int = 0
    private var throttleLatency: Int = 0
    private var throttlePacketLoss: Double = 0.0

    fun setListener(listener: ProxyListener?) {
        this.listener = listener
    }

    /**
     * Start the proxy server
     */
    fun start(port: Int, enableSsl: Boolean, bypassApps: List<String>) {
        if (isRunning.get()) {
            throw IllegalStateException("Proxy is already running")
        }

        this.port = port
        this.sslInterceptionEnabled = enableSsl
        this.bypassApps = bypassApps

        executorService = Executors.newCachedThreadPool()

        executorService?.execute {
            try {
                serverSocket = ServerSocket(port)
                isRunning.set(true)
                notifyStatusChanged()

                while (isRunning.get()) {
                    try {
                        val clientSocket = serverSocket?.accept() ?: break
                        activeConnections.incrementAndGet()
                        executorService?.execute {
                            handleConnection(clientSocket)
                            activeConnections.decrementAndGet()
                        }
                    } catch (e: Exception) {
                        if (isRunning.get()) {
                            listener?.onError("Accept error: ${e.message}")
                        }
                    }
                }
            } catch (e: Exception) {
                listener?.onError("Server error: ${e.message}")
            }
        }
    }

    /**
     * Stop the proxy server
     */
    fun stop() {
        isRunning.set(false)
        serverSocket?.close()
        serverSocket = null
        executorService?.shutdownNow()
        executorService = null
        flows.clear()
        notifyStatusChanged()
    }

    /**
     * Get current status
     */
    fun getStatus(): Map<String, Any> {
        return mapOf(
            "isRunning" to isRunning.get(),
            "port" to port,
            "activeConnections" to activeConnections.get(),
            "bytesReceived" to bytesReceived.get(),
            "bytesSent" to bytesSent.get(),
            "sslInterceptionEnabled" to sslInterceptionEnabled
        )
    }

    /**
     * Set proxy rules
     */
    fun setRules(rules: List<Map<String, Any>>) {
        this.rules = rules
    }

    /**
     * Set bypass apps
     */
    fun setBypassApps(packageNames: List<String>) {
        this.bypassApps = packageNames
    }

    /**
     * Pause a flow
     */
    fun pauseFlow(flowId: String) {
        flows[flowId]?.isPaused = true
    }

    /**
     * Resume a flow
     */
    fun resumeFlow(
        flowId: String,
        modifiedRequest: Map<String, Any>?,
        modifiedResponse: Map<String, Any>?
    ) {
        flows[flowId]?.let { flow ->
            flow.isPaused = false
            flow.modifiedRequest = modifiedRequest
            flow.modifiedResponse = modifiedResponse
            synchronized(flow) {
                (flow as Object).notifyAll()
            }
        }
    }

    /**
     * Abort a flow
     */
    fun abortFlow(flowId: String) {
        flows[flowId]?.let { flow ->
            flow.isAborted = true
            flow.isPaused = false
            synchronized(flow) {
                (flow as Object).notifyAll()
            }
        }
    }

    /**
     * Set throttling
     */
    fun setThrottling(download: Int, upload: Int, latency: Int, packetLoss: Double) {
        throttleDownload = download
        throttleUpload = upload
        throttleLatency = latency
        throttlePacketLoss = packetLoss
    }

    private fun handleConnection(clientSocket: Socket) {
        try {
            val reader = BufferedReader(InputStreamReader(clientSocket.getInputStream()))
            val writer = BufferedWriter(OutputStreamWriter(clientSocket.getOutputStream()))

            // Read request line
            val requestLine = reader.readLine() ?: return
            val parts = requestLine.split(" ")
            if (parts.size < 2) return

            val method = parts[0]
            val pathOrUrl = parts[1]

            // Read headers
            val headers = mutableMapOf<String, String>()
            var line: String?
            while (reader.readLine().also { line = it } != null && line!!.isNotEmpty()) {
                val colonIndex = line!!.indexOf(':')
                if (colonIndex > 0) {
                    val name = line!!.substring(0, colonIndex).trim()
                    val value = line!!.substring(colonIndex + 1).trim()
                    headers[name] = value
                }
            }

            // Create flow
            val flowId = "flow_${flowCounter.incrementAndGet()}_${System.currentTimeMillis()}"
            val flow = ProxyFlow(flowId)
            flows[flowId] = flow

            // Parse request
            val request = parseRequest(method, pathOrUrl, headers)
            flow.request = request

            // Check for breakpoint
            if (shouldPauseForBreakpoint(request)) {
                flow.isPaused = true
                notifyFlowCaptured(flow)
                waitForResume(flow)
                if (flow.isAborted) {
                    sendError(writer, 502, "Request aborted")
                    return
                }
            }

            // Handle CONNECT for HTTPS
            if (method == "CONNECT") {
                handleConnect(clientSocket, reader, writer, flow, request)
            } else {
                handleHttp(clientSocket, reader, writer, flow, request, requestLine, headers)
            }

        } catch (e: Exception) {
            listener?.onError("Connection error: ${e.message}")
        } finally {
            try {
                clientSocket.close()
            } catch (e: Exception) {
                // Ignore
            }
        }
    }

    private fun parseRequest(
        method: String,
        pathOrUrl: String,
        headers: Map<String, String>
    ): HttpRequest {
        val host: String
        var port = 80
        val scheme: String
        val path: String

        if (method == "CONNECT") {
            val hostPort = pathOrUrl.split(":")
            host = hostPort[0]
            port = if (hostPort.size > 1) hostPort[1].toIntOrNull() ?: 443 else 443
            scheme = "https"
            path = ""
        } else if (pathOrUrl.startsWith("http")) {
            val url = java.net.URL(pathOrUrl)
            host = url.host
            port = if (url.port != -1) url.port else if (url.protocol == "https") 443 else 80
            scheme = url.protocol
            path = url.path + (url.query?.let { "?$it" } ?: "")
        } else {
            host = headers["Host"] ?: "unknown"
            scheme = "http"
            path = pathOrUrl
        }

        val fullUrl = if (port == 80 || port == 443) {
            "$scheme://$host$path"
        } else {
            "$scheme://$host:$port$path"
        }

        return HttpRequest(
            method = method,
            url = fullUrl,
            scheme = scheme,
            host = host,
            port = port,
            path = path,
            headers = headers,
            timestamp = System.currentTimeMillis()
        )
    }

    private fun handleConnect(
        clientSocket: Socket,
        reader: BufferedReader,
        writer: BufferedWriter,
        flow: ProxyFlow,
        request: HttpRequest
    ) {
        // Send 200 Connection Established
        writer.write("HTTP/1.1 200 Connection Established\r\n\r\n")
        writer.flush()

        if (sslInterceptionEnabled) {
            handleSslInterception(clientSocket, flow, request)
        } else {
            handleDirectTunnel(clientSocket, request)
        }
    }

    private fun handleSslInterception(
        clientSocket: Socket,
        flow: ProxyFlow,
        request: HttpRequest
    ) {
        try {
            // Generate certificate for the host
            val (keyPair, cert) = certificateAuthority.generateCertificate(request.host)

            // Create SSL context with generated certificate
            val sslContext = SSLContext.getInstance("TLS")
            val keyManagerFactory = javax.net.ssl.KeyManagerFactory.getInstance(
                javax.net.ssl.KeyManagerFactory.getDefaultAlgorithm()
            )

            val keyStore = java.security.KeyStore.getInstance("PKCS12")
            keyStore.load(null, null)
            keyStore.setKeyEntry(
                "server",
                keyPair.private,
                "".toCharArray(),
                arrayOf(cert, certificateAuthority.getRootCertificateChain()[0])
            )
            keyManagerFactory.init(keyStore, "".toCharArray())

            sslContext.init(keyManagerFactory.keyManagers, null, null)

            // Wrap client socket with SSL (using socketFactory for wrapping existing socket)
            val sslSocketFactory = sslContext.socketFactory
            val sslSocket = sslSocketFactory.createSocket(
                clientSocket,
                request.host,
                request.port,
                true
            ) as SSLSocket
            sslSocket.useClientMode = false
            sslSocket.startHandshake()

            // Now handle HTTP over SSL
            val sslReader = BufferedReader(InputStreamReader(sslSocket.getInputStream()))
            val sslWriter = BufferedWriter(OutputStreamWriter(sslSocket.getOutputStream()))

            // Read the actual HTTP request
            val requestLine = sslReader.readLine() ?: return
            val parts = requestLine.split(" ")
            if (parts.size < 2) return

            val headers = mutableMapOf<String, String>()
            var line: String?
            while (sslReader.readLine().also { line = it } != null && line!!.isNotEmpty()) {
                val colonIndex = line!!.indexOf(':')
                if (colonIndex > 0) {
                    headers[line!!.substring(0, colonIndex).trim()] =
                        line!!.substring(colonIndex + 1).trim()
                }
            }

            // Update request
            val actualRequest = parseRequest(parts[0], parts[1], headers).copy(
                scheme = "https",
                host = request.host,
                port = request.port
            )
            flow.request = actualRequest

            // Forward to server
            forwardToServer(sslSocket, sslReader, sslWriter, flow, actualRequest, requestLine, headers)

        } catch (e: Exception) {
            listener?.onError("SSL interception error: ${e.message}")
            // Fallback to direct tunnel
            handleDirectTunnel(clientSocket, request)
        }
    }

    private fun handleDirectTunnel(clientSocket: Socket, request: HttpRequest) {
        try {
            val serverSocket = Socket()
            serverSocket.connect(InetSocketAddress(request.host, request.port), 10000)

            val clientToServer = Thread {
                try {
                    val buffer = ByteArray(8192)
                    var read: Int
                    while (clientSocket.getInputStream().read(buffer).also { read = it } != -1) {
                        serverSocket.getOutputStream().write(buffer, 0, read)
                        bytesSent.addAndGet(read.toLong())
                    }
                } catch (e: Exception) {
                    // Connection closed
                }
            }

            val serverToClient = Thread {
                try {
                    val buffer = ByteArray(8192)
                    var read: Int
                    while (serverSocket.getInputStream().read(buffer).also { read = it } != -1) {
                        clientSocket.getOutputStream().write(buffer, 0, read)
                        bytesReceived.addAndGet(read.toLong())
                    }
                } catch (e: Exception) {
                    // Connection closed
                }
            }

            clientToServer.start()
            serverToClient.start()
            clientToServer.join()
            serverToClient.join()

            serverSocket.close()
        } catch (e: Exception) {
            listener?.onError("Tunnel error: ${e.message}")
        }
    }

    private fun handleHttp(
        clientSocket: Socket,
        reader: BufferedReader,
        writer: BufferedWriter,
        flow: ProxyFlow,
        request: HttpRequest,
        requestLine: String,
        headers: Map<String, String>
    ) {
        forwardToServer(clientSocket, reader, writer, flow, request, requestLine, headers)
    }

    private fun forwardToServer(
        clientSocket: Socket,
        reader: BufferedReader,
        writer: BufferedWriter,
        flow: ProxyFlow,
        request: HttpRequest,
        requestLine: String,
        headers: Map<String, String>
    ) {
        try {
            // Apply throttling latency
            if (throttleLatency > 0) {
                Thread.sleep(throttleLatency.toLong())
            }

            // Connect to server
            val serverSocket = if (request.scheme == "https") {
                val sslContext = SSLContext.getInstance("TLS")
                sslContext.init(null, null, null)
                val factory = sslContext.socketFactory as SSLSocketFactory
                factory.createSocket(request.host, request.port) as SSLSocket
            } else {
                Socket(request.host, request.port)
            }

            val serverReader = BufferedReader(InputStreamReader(serverSocket.getInputStream()))
            val serverWriter = BufferedWriter(OutputStreamWriter(serverSocket.getOutputStream()))

            // Send request
            val path = if (request.path.isEmpty()) "/" else request.path
            serverWriter.write("${request.method} $path HTTP/1.1\r\n")
            headers.forEach { (name, value) ->
                serverWriter.write("$name: $value\r\n")
            }
            serverWriter.write("\r\n")
            serverWriter.flush()

            // Read body if present
            val contentLength = headers["Content-Length"]?.toIntOrNull() ?: 0
            if (contentLength > 0) {
                val body = CharArray(contentLength)
                reader.read(body, 0, contentLength)
                serverWriter.write(body)
                serverWriter.flush()
                bytesSent.addAndGet(contentLength.toLong())
            }

            // Read response
            val responseLine = serverReader.readLine() ?: return
            val responseParts = responseLine.split(" ", limit = 3)
            val statusCode = responseParts.getOrNull(1)?.toIntOrNull() ?: 0
            val statusMessage = responseParts.getOrNull(2) ?: ""

            val responseHeaders = mutableMapOf<String, String>()
            var line: String?
            while (serverReader.readLine().also { line = it } != null && line!!.isNotEmpty()) {
                val colonIndex = line!!.indexOf(':')
                if (colonIndex > 0) {
                    responseHeaders[line!!.substring(0, colonIndex).trim()] =
                        line!!.substring(colonIndex + 1).trim()
                }
            }

            // Update flow with response
            flow.response = HttpResponse(
                statusCode = statusCode,
                statusMessage = statusMessage,
                headers = responseHeaders,
                timestamp = System.currentTimeMillis()
            )
            flow.state = "completed"
            notifyFlowCaptured(flow)

            // Forward response to client
            writer.write("$responseLine\r\n")
            responseHeaders.forEach { (name, value) ->
                writer.write("$name: $value\r\n")
            }
            writer.write("\r\n")
            writer.flush()

            // Forward body
            val responseContentLength = responseHeaders["Content-Length"]?.toIntOrNull()
            if (responseContentLength != null && responseContentLength > 0) {
                val body = CharArray(responseContentLength)
                serverReader.read(body, 0, responseContentLength)
                writer.write(body)
                writer.flush()
                bytesReceived.addAndGet(responseContentLength.toLong())
            }

            serverSocket.close()

        } catch (e: Exception) {
            flow.state = "failed"
            flow.error = e.message
            notifyFlowCaptured(flow)
            listener?.onError("Forward error: ${e.message}")
        }
    }

    private fun shouldPauseForBreakpoint(request: HttpRequest): Boolean {
        return rules.any { rule ->
            rule["type"] == "breakpoint" &&
                    rule["isEnabled"] == true &&
                    matchesRule(request, rule["matcher"] as? Map<String, Any>)
        }
    }

    private fun matchesRule(request: HttpRequest, matcher: Map<String, Any>?): Boolean {
        if (matcher == null) return false
        val pattern = matcher["pattern"] as? String ?: return false
        return request.url.contains(pattern)
    }

    private fun waitForResume(flow: ProxyFlow) {
        synchronized(flow) {
            while (flow.isPaused && !flow.isAborted) {
                try {
                    (flow as Object).wait()
                } catch (e: InterruptedException) {
                    break
                }
            }
        }
    }

    private fun sendError(writer: BufferedWriter, code: Int, message: String) {
        try {
            writer.write("HTTP/1.1 $code $message\r\n")
            writer.write("Content-Length: 0\r\n")
            writer.write("\r\n")
            writer.flush()
        } catch (e: Exception) {
            // Ignore
        }
    }

    private fun notifyFlowCaptured(flow: ProxyFlow) {
        listener?.onFlowCaptured(flow.toMap())
    }

    private fun notifyStatusChanged() {
        listener?.onStatusChanged(getStatus())
    }
}

/**
 * Represents an HTTP request
 */
data class HttpRequest(
    val method: String,
    val url: String,
    val scheme: String,
    val host: String,
    val port: Int,
    val path: String,
    val headers: Map<String, String>,
    val body: String? = null,
    val timestamp: Long
) {
    fun toMap(): Map<String, Any> {
        return mapOf(
            "method" to method,
            "url" to url,
            "scheme" to scheme,
            "host" to host,
            "port" to port,
            "path" to path,
            "headers" to headers,
            "timestamp" to timestamp
        ).let { map ->
            body?.let { map + ("bodyText" to it) } ?: map
        }
    }
}

/**
 * Represents an HTTP response
 */
data class HttpResponse(
    val statusCode: Int,
    val statusMessage: String,
    val headers: Map<String, String>,
    val body: String? = null,
    val timestamp: Long
) {
    fun toMap(): Map<String, Any> {
        return mapOf(
            "statusCode" to statusCode,
            "statusMessage" to statusMessage,
            "headers" to headers,
            "timestamp" to timestamp
        ).let { map ->
            body?.let { map + ("bodyText" to it) } ?: map
        }
    }
}

/**
 * Represents a proxy flow
 */
class ProxyFlow(val id: String) {
    var request: HttpRequest? = null
    var response: HttpResponse? = null
    var state: String = "pending"
    var error: String? = null
    var isPaused: Boolean = false
    var isAborted: Boolean = false
    var modifiedRequest: Map<String, Any>? = null
    var modifiedResponse: Map<String, Any>? = null

    fun toMap(): Map<String, Any> {
        val map = mutableMapOf<String, Any>(
            "id" to id,
            "state" to state
        )
        request?.let { map["request"] = it.toMap() }
        response?.let { map["response"] = it.toMap() }
        error?.let { map["error"] = it }
        return map
    }
}
