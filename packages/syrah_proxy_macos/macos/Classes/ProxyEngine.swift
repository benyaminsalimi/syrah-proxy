import Foundation
import Network
import Security

/// Delegate protocol for proxy engine events
protocol ProxyEngineDelegate: AnyObject {
    func proxyEngine(_ engine: ProxyEngine, didCaptureFlow flow: [String: Any])
    func proxyEngine(_ engine: ProxyEngine, didUpdateStatus status: [String: Any])
    func proxyEngine(_ engine: ProxyEngine, didEncounterError error: Error)
}

/// Proxy engine errors
enum ProxyEngineError: Error, LocalizedError {
    case alreadyRunning
    case notRunning
    case bindFailed
    case connectionFailed
    case sslError

    var errorDescription: String? {
        switch self {
        case .alreadyRunning:
            return "Proxy is already running"
        case .notRunning:
            return "Proxy is not running"
        case .bindFailed:
            return "Failed to bind to port"
        case .connectionFailed:
            return "Connection failed"
        case .sslError:
            return "SSL/TLS error"
        }
    }
}

/// Flow state for tracking request/response
class ProxyFlow {
    let id: String
    var request: HTTPRequest?
    var response: HTTPResponse?
    var state: FlowState = .pending
    var isPaused: Bool = false
    var continuation: CheckedContinuation<Void, Error>?

    init(id: String) {
        self.id = id
    }

    enum FlowState: String {
        case pending
        case waiting
        case receiving
        case completed
        case failed
        case paused
    }

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "state": state.rawValue
        ]

        if let req = request {
            dict["request"] = req.toDictionary()
        }

        if let res = response {
            dict["response"] = res.toDictionary()
        }

        return dict
    }
}

/// HTTP request representation
struct HTTPRequest {
    let method: String
    let url: String
    let scheme: String
    let host: String
    let port: Int
    let path: String
    let queryString: String?
    let headers: [String: String]
    let body: Data?
    let timestamp: Date

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "method": method,
            "url": url,
            "scheme": scheme,
            "host": host,
            "port": port,
            "path": path,
            "headers": headers,
            "timestamp": timestamp.timeIntervalSince1970 * 1000
        ]

        if let qs = queryString {
            dict["queryString"] = qs
        }

        if let bodyData = body {
            if let bodyString = String(data: bodyData, encoding: .utf8) {
                dict["bodyText"] = bodyString
            }
            dict["contentLength"] = bodyData.count
        }

        return dict
    }
}

/// HTTP response representation
struct HTTPResponse {
    let statusCode: Int
    let statusMessage: String
    let headers: [String: String]
    let body: Data?
    let timestamp: Date

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "statusCode": statusCode,
            "statusMessage": statusMessage,
            "headers": headers,
            "timestamp": timestamp.timeIntervalSince1970 * 1000
        ]

        if let bodyData = body {
            if let bodyString = String(data: bodyData, encoding: .utf8) {
                dict["bodyText"] = bodyString
            }
            dict["contentLength"] = bodyData.count
        }

        return dict
    }
}

/// Main proxy engine for intercepting HTTP/HTTPS traffic
class ProxyEngine {
    weak var delegate: ProxyEngineDelegate?

    private let certificateAuthority: CertificateAuthority

    private var listener: NWListener?
    private var connections: [String: NWConnection] = [:]
    private var flows: [String: ProxyFlow] = [:]
    private var rules: [[String: Any]] = []
    private var tunneledConnections: Set<String> = []  // Track connections that have been tunneled

    // Throttling settings
    private var throttleDownload: Int = 0
    private var throttleUpload: Int = 0
    private var throttleLatency: Int = 0
    private var throttlePacketLoss: Double = 0

    // Bypass hosts
    private var bypassHosts: Set<String> = []

    // Statistics
    private(set) var bytesReceived: Int = 0
    private(set) var bytesSent: Int = 0

    // Configuration
    private(set) var port: UInt16 = 8888
    private(set) var bindAddress: String = "127.0.0.1"
    private(set) var sslInterceptionEnabled: Bool = true

    private let queue = DispatchQueue(label: "dev.syrah.proxy", qos: .userInitiated)
    private var flowCounter: Int = 0

    var isRunning: Bool {
        return listener?.state == .ready
    }

    var activeConnections: Int {
        return connections.count
    }

    init(certificateAuthority: CertificateAuthority) {
        self.certificateAuthority = certificateAuthority
    }

    // MARK: - Lifecycle

    /// Start the proxy server
    func start(port: UInt16, bindAddress: String, enableSslInterception: Bool, bypassHosts: [String]) throws {
        guard !isRunning else {
            throw ProxyEngineError.alreadyRunning
        }

        self.port = port
        self.bindAddress = bindAddress
        self.sslInterceptionEnabled = enableSslInterception
        self.bypassHosts = Set(bypassHosts)

        // Create TCP listener
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true

        let host = NWEndpoint.Host(bindAddress)
        let nwPort = NWEndpoint.Port(rawValue: port)!

        do {
            listener = try NWListener(using: parameters, on: nwPort)
        } catch {
            throw ProxyEngineError.bindFailed
        }

        listener?.stateUpdateHandler = { [weak self] state in
            self?.handleListenerState(state)
        }

        listener?.newConnectionHandler = { [weak self] connection in
            self?.handleNewConnection(connection)
        }

        listener?.start(queue: queue)

        notifyStatusUpdate()
    }

    /// Stop the proxy server
    func stop() {
        listener?.cancel()
        listener = nil

        // Close all connections
        for (_, connection) in connections {
            connection.cancel()
        }
        connections.removeAll()
        flows.removeAll()

        notifyStatusUpdate()
    }

    // MARK: - Connection Handling

    private func handleListenerState(_ state: NWListener.State) {
        switch state {
        case .ready:
            print("Proxy listening on \(bindAddress):\(port)")
        case .failed(let error):
            delegate?.proxyEngine(self, didEncounterError: error)
        case .cancelled:
            print("Proxy stopped")
        default:
            break
        }

        notifyStatusUpdate()
    }

    private func handleNewConnection(_ connection: NWConnection) {
        let connectionId = UUID().uuidString
        connections[connectionId] = connection
        print("[ProxyEngine] New connection: \(connectionId)")

        connection.stateUpdateHandler = { [weak self] state in
            self?.handleConnectionState(connectionId: connectionId, connection: connection, state: state)
        }

        connection.start(queue: queue)
    }

    private func handleConnectionState(connectionId: String, connection: NWConnection, state: NWConnection.State) {
        print("[ProxyEngine] Connection \(connectionId) state: \(state)")
        switch state {
        case .ready:
            print("[ProxyEngine] Connection ready, starting to receive data...")
            // Start receiving data only when connection is ready
            receiveData(connectionId: connectionId, connection: connection)
        case .failed(let error):
            delegate?.proxyEngine(self, didEncounterError: error)
            connections.removeValue(forKey: connectionId)
            tunneledConnections.remove(connectionId)
        case .cancelled:
            connections.removeValue(forKey: connectionId)
            tunneledConnections.remove(connectionId)
        default:
            break
        }
    }

    private func receiveData(connectionId: String, connection: NWConnection) {
        print("[ProxyEngine] Setting up receive for connection \(connectionId)")
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] content, context, isComplete, error in
            guard let self = self else {
                print("[ProxyEngine] Self is nil in receive callback")
                return
            }

            // Check if this connection has been tunneled (CONNECT request handled)
            if self.tunneledConnections.contains(connectionId) {
                print("[ProxyEngine] Connection \(connectionId) is tunneled, stopping receive loop")
                return
            }

            print("[ProxyEngine] Receive callback - content: \(content?.count ?? 0) bytes, isComplete: \(isComplete), error: \(String(describing: error))")

            if let error = error {
                print("[ProxyEngine] Receive error: \(error)")
                self.delegate?.proxyEngine(self, didEncounterError: error)
                return
            }

            if let data = content, !data.isEmpty {
                self.bytesReceived += data.count
                let isTunneled = self.handleIncomingData(connectionId: connectionId, connection: connection, data: data)
                if isTunneled {
                    return  // Stop the receive loop immediately
                }
            }

            // Don't continue the receive loop if this connection has been tunneled
            if self.tunneledConnections.contains(connectionId) {
                print("[ProxyEngine] Connection \(connectionId) was tunneled during handling, stopping receive loop")
                return
            }

            if !isComplete {
                self.receiveData(connectionId: connectionId, connection: connection)
            } else {
                print("[ProxyEngine] Connection \(connectionId) receive completed")
            }
        }
    }

    /// Handle incoming data from client. Returns true if the connection was tunneled (CONNECT).
    @discardableResult
    private func handleIncomingData(connectionId: String, connection: NWConnection, data: Data) -> Bool {
        print("[ProxyEngine] Received \(data.count) bytes from client")

        // Parse HTTP request
        guard let request = parseHTTPRequest(data) else {
            print("[ProxyEngine] Failed to parse HTTP request")
            if let str = String(data: data, encoding: .utf8) {
                print("[ProxyEngine] Raw data: \(str.prefix(200))")
            }
            return false
        }

        print("[ProxyEngine] Parsed request: \(request.method) \(request.url)")

        // Create flow
        flowCounter += 1
        let flowId = "flow_\(flowCounter)_\(Int(Date().timeIntervalSince1970 * 1000))"
        let flow = ProxyFlow(id: flowId)
        flow.request = request
        flow.state = .waiting
        flows[flowId] = flow

        // Check if we should bypass this host
        if shouldBypass(host: request.host) {
            print("[ProxyEngine] Bypassing host: \(request.host)")
            forwardRequestDirect(flow: flow, connection: connection)
            return false
        } else {
            // Check rules for breakpoints
            if shouldPauseForBreakpoint(request: request) {
                flow.state = .paused
                flow.isPaused = true
            }

            // Notify delegate
            delegate?.proxyEngine(self, didCaptureFlow: flow.toDictionary())

            // Forward request (with potential SSL interception)
            if request.method == "CONNECT" {
                print("[ProxyEngine] Handling CONNECT request - marking connection as tunneled")
                tunneledConnections.insert(connectionId)
                handleConnectRequest(flow: flow, connection: connection)
                return true  // Connection is now tunneled
            } else {
                print("[ProxyEngine] Forwarding HTTP request")
                forwardRequest(flow: flow, connection: connection)
                return false
            }
        }
    }

    // MARK: - HTTP Parsing

    private func parseHTTPRequest(_ data: Data) -> HTTPRequest? {
        guard let requestString = String(data: data, encoding: .utf8) else {
            return nil
        }

        let lines = requestString.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else {
            return nil
        }

        // Parse request line: METHOD PATH HTTP/VERSION
        let parts = requestLine.components(separatedBy: " ")
        guard parts.count >= 2 else {
            return nil
        }

        let method = parts[0]
        let pathOrUrl = parts[1]

        // Parse headers
        var headers: [String: String] = [:]
        var headerEndIndex = 0
        for (index, line) in lines.enumerated() {
            if index == 0 { continue }
            if line.isEmpty {
                headerEndIndex = index
                break
            }
            if let colonIndex = line.firstIndex(of: ":") {
                let name = String(line[..<colonIndex]).trimmingCharacters(in: .whitespaces)
                let value = String(line[line.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                headers[name] = value
            }
        }

        // Extract body
        var body: Data?
        if headerEndIndex > 0 && headerEndIndex < lines.count - 1 {
            let bodyString = lines[(headerEndIndex + 1)...].joined(separator: "\r\n")
            body = bodyString.data(using: .utf8)
        }

        // Determine host, port, and scheme
        let host: String
        var port = 80
        let scheme: String
        let path: String

        if method == "CONNECT" {
            // CONNECT hostname:port
            let hostPort = pathOrUrl.components(separatedBy: ":")
            host = hostPort[0]
            port = hostPort.count > 1 ? Int(hostPort[1]) ?? 443 : 443
            scheme = "https"
            path = ""
        } else if pathOrUrl.hasPrefix("http") {
            // Absolute URL
            if let url = URL(string: pathOrUrl) {
                host = url.host ?? headers["Host"] ?? "unknown"
                port = url.port ?? (url.scheme == "https" ? 443 : 80)
                scheme = url.scheme ?? "http"
                path = url.path + (url.query.map { "?\($0)" } ?? "")
            } else {
                host = headers["Host"] ?? "unknown"
                scheme = "http"
                path = pathOrUrl
            }
        } else {
            // Relative URL
            host = headers["Host"] ?? "unknown"
            scheme = "http"
            path = pathOrUrl
        }

        let queryString = path.contains("?") ? String(path.split(separator: "?").last ?? "") : nil

        let fullUrl: String
        if port == 80 || port == 443 {
            fullUrl = "\(scheme)://\(host)\(path)"
        } else {
            fullUrl = "\(scheme)://\(host):\(port)\(path)"
        }

        return HTTPRequest(
            method: method,
            url: fullUrl,
            scheme: scheme,
            host: host,
            port: port,
            path: path,
            queryString: queryString,
            headers: headers,
            body: body,
            timestamp: Date()
        )
    }

    // MARK: - Request Forwarding

    private func handleConnectRequest(flow: ProxyFlow, connection: NWConnection) {
        guard let request = flow.request else { return }

        // Send 200 Connection Established
        let response = "HTTP/1.1 200 Connection Established\r\n\r\n"
        connection.send(content: response.data(using: .utf8), completion: .contentProcessed { [weak self] error in
            if let error = error {
                self?.delegate?.proxyEngine(self!, didEncounterError: error)
                return
            }

            // Now set up TLS interception if enabled
            if self?.sslInterceptionEnabled == true {
                self?.setupTLSInterception(flow: flow, connection: connection)
            } else {
                // Direct tunneling without interception
                self?.setupDirectTunnel(flow: flow, connection: connection)
            }
        })
    }

    /// TLS interception state for a connection
    private class TLSInterceptionState {
        let flow: ProxyFlow
        let clientConnection: NWConnection
        var targetConnection: NWConnection?
        var sslContext: SSLContext?
        var readBuffer: Data = Data()
        var writeBuffer: Data = Data()
        var handshakeComplete: Bool = false
        weak var engine: ProxyEngine?

        init(flow: ProxyFlow, clientConnection: NWConnection, engine: ProxyEngine) {
            self.flow = flow
            self.clientConnection = clientConnection
            self.engine = engine
        }

        func flushWriteBuffer() {
            guard !writeBuffer.isEmpty else { return }
            let dataToSend = writeBuffer
            writeBuffer = Data()
            clientConnection.send(content: dataToSend, completion: .contentProcessed { error in
                if let error = error {
                    print("[ProxyEngine] TLS write flush error: \(error)")
                }
            })
        }
    }

    private var tlsStates: [String: TLSInterceptionState] = [:]

    private func setupTLSInterception(flow: ProxyFlow, connection: NWConnection) {
        guard let request = flow.request else { return }

        print("[ProxyEngine] Setting up TLS interception for \(request.host):\(request.port)")

        // TLS interception with SecureTransport has compatibility issues with async NWConnection
        // For now, use direct tunneling and mark the flow as encrypted
        // TODO: Implement proper TLS MITM using POSIX sockets or different approach

        // Update flow to indicate encrypted tunnel
        flow.state = .completed

        // Create a response to indicate tunnel established
        flow.response = HTTPResponse(
            statusCode: 200,
            statusMessage: "Connection Established (Encrypted Tunnel)",
            headers: ["X-Syrah-Tunnel": "encrypted"],
            body: nil,
            timestamp: Date()
        )

        // Notify delegate with updated flow
        delegate?.proxyEngine(self, didCaptureFlow: flow.toDictionary())

        // Use direct tunneling for now
        setupDirectTunnel(flow: flow, connection: connection)
    }

    // Keep the TLS-related methods for future use
    private func setupTLSInterceptionFull(flow: ProxyFlow, connection: NWConnection) {
        guard let request = flow.request else { return }

        do {
            let identity = try certificateAuthority.generateCertificate(for: request.host)

            var certRef: SecCertificate?
            SecIdentityCopyCertificate(identity, &certRef)

            guard certRef != nil else {
                throw ProxyEngineError.sslError
            }

            guard let sslContext = SSLCreateContext(nil, .serverSide, .streamType) else {
                throw ProxyEngineError.sslError
            }

            var certFromIdentity: SecCertificate?
            SecIdentityCopyCertificate(identity, &certFromIdentity)
            if let cert = certFromIdentity {
                print("[ProxyEngine] Certificate subject: \(SecCertificateCopySubjectSummary(cert) ?? "unknown" as CFString)")
            }

            let certs: [Any] = [identity]
            let status = SSLSetCertificate(sslContext, certs as CFArray)
            if status != noErr {
                throw ProxyEngineError.sslError
            }

            let state = TLSInterceptionState(flow: flow, clientConnection: connection, engine: self)
            state.sslContext = sslContext
            tlsStates[flow.id] = state

            let statePtr = Unmanaged.passUnretained(state).toOpaque()
            SSLSetConnection(sslContext, statePtr)
            SSLSetIOFuncs(sslContext, { (connectionRef, data, dataLength) -> OSStatus in
                let state = Unmanaged<TLSInterceptionState>.fromOpaque(connectionRef).takeUnretainedValue()
                return state.engine?.tlsRead(state: state, data: data, dataLength: dataLength) ?? errSSLInternal
            }, { (connectionRef, data, dataLength) -> OSStatus in
                let state = Unmanaged<TLSInterceptionState>.fromOpaque(connectionRef).takeUnretainedValue()
                return state.engine?.tlsWrite(state: state, data: data, dataLength: dataLength) ?? errSSLInternal
            })

            let targetHost = NWEndpoint.Host(request.host)
            let targetPort = NWEndpoint.Port(rawValue: UInt16(request.port))!

            let tlsOptions = NWProtocolTLS.Options()
            sec_protocol_options_set_verify_block(tlsOptions.securityProtocolOptions, { (_, _, completion) in
                completion(true)
            }, queue)

            let parameters = NWParameters(tls: tlsOptions)
            let targetConnection = NWConnection(host: targetHost, port: targetPort, using: parameters)
            state.targetConnection = targetConnection

            targetConnection.stateUpdateHandler = { [weak self, weak state] connState in
                guard let self = self, let state = state else { return }
                switch connState {
                case .ready:
                    self.startClientTLSHandshake(state: state)
                case .failed(let error):
                    self.cleanupTLSState(flowId: state.flow.id)
                    self.setupDirectTunnel(flow: state.flow, connection: state.clientConnection)
                default:
                    break
                }
            }

            targetConnection.start(queue: queue)

        } catch {
            setupDirectTunnel(flow: flow, connection: connection)
        }
    }

    private func tlsRead(state: TLSInterceptionState, data: UnsafeMutableRawPointer?, dataLength: UnsafeMutablePointer<Int>?) -> OSStatus {
        guard let data = data, let dataLength = dataLength else { return errSSLInternal }

        let requestedLength = dataLength.pointee

        if state.readBuffer.count >= requestedLength {
            state.readBuffer.copyBytes(to: data.assumingMemoryBound(to: UInt8.self), count: requestedLength)
            state.readBuffer.removeFirst(requestedLength)
            return noErr
        } else if state.readBuffer.count > 0 {
            let available = state.readBuffer.count
            state.readBuffer.copyBytes(to: data.assumingMemoryBound(to: UInt8.self), count: available)
            state.readBuffer.removeAll()
            dataLength.pointee = available
            return errSSLWouldBlock
        } else {
            dataLength.pointee = 0
            return errSSLWouldBlock
        }
    }

    private func tlsWrite(state: TLSInterceptionState, data: UnsafeRawPointer?, dataLength: UnsafeMutablePointer<Int>?) -> OSStatus {
        guard let data = data, let dataLength = dataLength else { return errSSLInternal }

        let length = dataLength.pointee
        let writeData = Data(bytes: data, count: length)

        // Buffer the write - will be flushed after SSLHandshake returns
        state.writeBuffer.append(writeData)
        print("[ProxyEngine] TLS write buffered: \(length) bytes (total: \(state.writeBuffer.count))")

        return noErr
    }

    private func startClientTLSHandshake(state: TLSInterceptionState) {
        guard let sslContext = state.sslContext else { return }

        // Start receiving data from client
        receiveClientTLSData(state: state)

        // Attempt handshake (will likely return wouldBlock until we have data)
        continueTLSHandshake(state: state)
    }

    private func receiveClientTLSData(state: TLSInterceptionState) {
        print("[ProxyEngine] receiveClientTLSData: waiting for data...")
        state.clientConnection.receive(minimumIncompleteLength: 1, maximumLength: 16384) { [weak self, weak state] content, context, isComplete, error in
            guard let self = self, let state = state else { return }

            print("[ProxyEngine] receiveClientTLSData: received callback - content: \(content?.count ?? 0) bytes, isComplete: \(isComplete), error: \(String(describing: error))")

            if let error = error {
                print("[ProxyEngine] Client TLS receive error: \(error)")
                self.cleanupTLSState(flowId: state.flow.id)
                return
            }

            if let data = content, !data.isEmpty {
                print("[ProxyEngine] Client TLS data received: \(data.count) bytes, first bytes: \(data.prefix(16).map { String(format: "%02X", $0) }.joined(separator: " "))")
                state.readBuffer.append(data)
                print("[ProxyEngine] readBuffer now has \(state.readBuffer.count) bytes")

                if !state.handshakeComplete {
                    self.continueTLSHandshake(state: state)
                } else {
                    self.processDecryptedClientData(state: state)
                }
            }

            if !isComplete {
                self.receiveClientTLSData(state: state)
            }
        }
    }

    private func continueTLSHandshake(state: TLSInterceptionState) {
        guard let sslContext = state.sslContext else { return }

        print("[ProxyEngine] continueTLSHandshake called, readBuffer: \(state.readBuffer.count) bytes")
        let status = SSLHandshake(sslContext)
        print("[ProxyEngine] SSLHandshake returned: \(status)")

        // Flush any buffered writes after each handshake step
        state.flushWriteBuffer()

        switch status {
        case noErr:
            print("[ProxyEngine] TLS handshake completed successfully!")
            state.handshakeComplete = true
            // Start receiving from target server
            receiveTargetData(state: state)
            // Process any pending client data
            if !state.readBuffer.isEmpty {
                processDecryptedClientData(state: state)
            }
        case errSSLWouldBlock:
            // Need more data, wait for next receive
            print("[ProxyEngine] TLS handshake needs more data (readBuffer: \(state.readBuffer.count) bytes)")
        default:
            print("[ProxyEngine] TLS handshake failed: \(status)")
            cleanupTLSState(flowId: state.flow.id)
            setupDirectTunnel(flow: state.flow, connection: state.clientConnection)
        }
    }

    private func processDecryptedClientData(state: TLSInterceptionState) {
        guard let sslContext = state.sslContext, state.handshakeComplete else { return }

        // Read decrypted data from SSL context
        var buffer = [UInt8](repeating: 0, count: 16384)
        var bytesRead: Int = 0

        let status = SSLRead(sslContext, &buffer, buffer.count, &bytesRead)

        if status == noErr || status == errSSLWouldBlock {
            if bytesRead > 0 {
                let decryptedData = Data(buffer.prefix(bytesRead))
                print("[ProxyEngine] Decrypted \(bytesRead) bytes from client")

                // Parse as HTTP request
                if let httpRequest = parseHTTPRequest(decryptedData) {
                    print("[ProxyEngine] Intercepted HTTPS request: \(httpRequest.method) \(httpRequest.url)")

                    // Create a new flow for this request
                    flowCounter += 1
                    let flowId = "flow_\(flowCounter)_\(Int(Date().timeIntervalSince1970 * 1000))"
                    let flow = ProxyFlow(id: flowId)

                    // Update the request with correct scheme
                    let httpsRequest = HTTPRequest(
                        method: httpRequest.method,
                        url: "https://\(state.flow.request?.host ?? "")\(httpRequest.path)",
                        scheme: "https",
                        host: state.flow.request?.host ?? httpRequest.host,
                        port: state.flow.request?.port ?? 443,
                        path: httpRequest.path,
                        queryString: httpRequest.queryString,
                        headers: httpRequest.headers,
                        body: httpRequest.body,
                        timestamp: httpRequest.timestamp
                    )

                    flow.request = httpsRequest
                    flow.state = .waiting
                    flows[flowId] = flow

                    // Notify delegate of the new decrypted flow
                    delegate?.proxyEngine(self, didCaptureFlow: flow.toDictionary())

                    // Forward to target server
                    forwardToTarget(state: state, flow: flow, data: decryptedData)
                } else {
                    // Not parseable as HTTP, forward raw
                    forwardRawToTarget(state: state, data: decryptedData)
                }
            }
        } else if status != errSSLClosedGraceful && status != errSSLClosedAbort {
            print("[ProxyEngine] SSLRead error: \(status)")
        }
    }

    private func forwardToTarget(state: TLSInterceptionState, flow: ProxyFlow, data: Data) {
        guard let targetConnection = state.targetConnection else { return }

        targetConnection.send(content: data, completion: .contentProcessed { [weak self] error in
            if let error = error {
                print("[ProxyEngine] Error sending to target: \(error)")
                self?.handleFlowError(flow: flow, error: error)
            }
        })
    }

    private func forwardRawToTarget(state: TLSInterceptionState, data: Data) {
        guard let targetConnection = state.targetConnection else { return }

        targetConnection.send(content: data, completion: .contentProcessed { error in
            if let error = error {
                print("[ProxyEngine] Error sending raw to target: \(error)")
            }
        })
    }

    private func receiveTargetData(state: TLSInterceptionState) {
        guard let targetConnection = state.targetConnection else { return }

        targetConnection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self, weak state] content, context, isComplete, error in
            guard let self = self, let state = state else { return }

            if let error = error {
                print("[ProxyEngine] Target receive error: \(error)")
                return
            }

            if let data = content, !data.isEmpty {
                print("[ProxyEngine] Received \(data.count) bytes from target")

                // Parse response to capture it
                if let response = self.parseHTTPResponse(data) {
                    print("[ProxyEngine] Intercepted HTTPS response: \(response.statusCode)")

                    // Find the most recent flow and update it
                    if let lastFlowId = self.flows.keys.sorted().last,
                       let flow = self.flows[lastFlowId] {
                        flow.response = response
                        flow.state = .completed
                        self.delegate?.proxyEngine(self, didCaptureFlow: flow.toDictionary())
                    }
                }

                // Encrypt and send to client
                self.sendEncryptedToClient(state: state, data: data)
            }

            if !isComplete {
                self.receiveTargetData(state: state)
            }
        }
    }

    private func sendEncryptedToClient(state: TLSInterceptionState, data: Data) {
        guard let sslContext = state.sslContext, state.handshakeComplete else { return }

        var bytesWritten: Int = 0
        data.withUnsafeBytes { buffer in
            let status = SSLWrite(sslContext, buffer.baseAddress, data.count, &bytesWritten)
            if status != noErr {
                print("[ProxyEngine] SSLWrite error: \(status)")
            }
        }
    }

    private func cleanupTLSState(flowId: String) {
        if let state = tlsStates.removeValue(forKey: flowId) {
            if let sslContext = state.sslContext {
                SSLClose(sslContext)
            }
            state.targetConnection?.cancel()
        }
    }

    private func setupDirectTunnel(flow: ProxyFlow, connection: NWConnection) {
        guard let request = flow.request else { return }

        print("[ProxyEngine] Setting up direct tunnel to \(request.host):\(request.port)")

        // Connect to target server
        let targetHost = NWEndpoint.Host(request.host)
        let targetPort = NWEndpoint.Port(rawValue: UInt16(request.port))!

        let parameters = NWParameters.tcp
        let targetConnection = NWConnection(host: targetHost, port: targetPort, using: parameters)

        targetConnection.stateUpdateHandler = { [weak self] state in
            print("[ProxyEngine] Tunnel target connection state: \(state)")
            switch state {
            case .ready:
                print("[ProxyEngine] Tunnel ready, starting bidirectional relay")
                // Start bidirectional relay
                self?.relayData(from: connection, to: targetConnection, label: "client->target")
                self?.relayData(from: targetConnection, to: connection, label: "target->client")
            case .failed(let error):
                print("[ProxyEngine] Tunnel failed: \(error)")
                self?.delegate?.proxyEngine(self!, didEncounterError: error)
                connection.cancel()
            case .waiting(let error):
                print("[ProxyEngine] Tunnel waiting: \(error)")
            default:
                break
            }
        }

        targetConnection.start(queue: queue)
    }

    private func relayData(from source: NWConnection, to destination: NWConnection, label: String) {
        source.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] content, context, isComplete, error in
            guard let self = self else { return }

            if let data = content, !data.isEmpty {
                print("[ProxyEngine] Relay[\(label)]: \(data.count) bytes")
                destination.send(content: data, completion: .contentProcessed { sendError in
                    if let sendError = sendError {
                        print("[ProxyEngine] Relay[\(label)] send error: \(sendError)")
                    }
                })
            }

            if let error = error {
                print("[ProxyEngine] Relay[\(label)] receive error: \(error)")
                return
            }

            if isComplete {
                print("[ProxyEngine] Relay[\(label)] completed")
            } else {
                self.relayData(from: source, to: destination, label: label)
            }
        }
    }

    private func forwardRequest(flow: ProxyFlow, connection: NWConnection) {
        guard let request = flow.request else {
            print("[ProxyEngine] forwardRequest: No request in flow")
            return
        }

        print("[ProxyEngine] Forwarding request to \(request.host):\(request.port) path=\(request.path)")

        // Connect to target server
        let targetHost = NWEndpoint.Host(request.host)
        let targetPort = NWEndpoint.Port(rawValue: UInt16(request.port))!

        let parameters: NWParameters
        if request.scheme == "https" {
            parameters = NWParameters.tls
        } else {
            parameters = NWParameters.tcp
        }

        let targetConnection = NWConnection(host: targetHost, port: targetPort, using: parameters)

        targetConnection.stateUpdateHandler = { [weak self] state in
            print("[ProxyEngine] Target connection state: \(state)")
            switch state {
            case .ready:
                print("[ProxyEngine] Target connection ready, sending request...")
                self?.sendRequestToTarget(flow: flow, clientConnection: connection, targetConnection: targetConnection)
            case .failed(let error):
                print("[ProxyEngine] Target connection failed: \(error)")
                self?.handleFlowError(flow: flow, error: error)
                connection.cancel()
            case .waiting(let error):
                print("[ProxyEngine] Target connection waiting: \(error)")
            default:
                break
            }
        }

        targetConnection.start(queue: queue)
    }

    private func forwardRequestDirect(flow: ProxyFlow, connection: NWConnection) {
        forwardRequest(flow: flow, connection: connection)
    }

    private func sendRequestToTarget(flow: ProxyFlow, clientConnection: NWConnection, targetConnection: NWConnection) {
        guard let request = flow.request else { return }

        // Rebuild HTTP request
        var requestData = "\(request.method) \(request.path.isEmpty ? "/" : request.path) HTTP/1.1\r\n"
        for (name, value) in request.headers {
            requestData += "\(name): \(value)\r\n"
        }
        requestData += "\r\n"

        var fullData = requestData.data(using: .utf8)!
        if let body = request.body {
            fullData.append(body)
        }

        print("[ProxyEngine] Sending request to target: \(String(data: fullData, encoding: .utf8)?.prefix(200) ?? "nil")")

        bytesSent += fullData.count

        // Apply throttling latency
        let sendDelay = throttleLatency > 0 ? DispatchTimeInterval.milliseconds(throttleLatency) : DispatchTimeInterval.never

        if throttleLatency > 0 {
            queue.asyncAfter(deadline: .now() + sendDelay) { [weak self] in
                self?.doSendRequest(data: fullData, flow: flow, clientConnection: clientConnection, targetConnection: targetConnection)
            }
        } else {
            doSendRequest(data: fullData, flow: flow, clientConnection: clientConnection, targetConnection: targetConnection)
        }
    }

    private func doSendRequest(data: Data, flow: ProxyFlow, clientConnection: NWConnection, targetConnection: NWConnection) {
        print("[ProxyEngine] Sending \(data.count) bytes to target")
        targetConnection.send(content: data, completion: .contentProcessed { [weak self] error in
            if let error = error {
                print("[ProxyEngine] Error sending to target: \(error)")
                self?.handleFlowError(flow: flow, error: error)
                return
            }

            print("[ProxyEngine] Send completed, now receiving response...")
            // Receive response
            self?.receiveResponse(flow: flow, clientConnection: clientConnection, targetConnection: targetConnection)
        })
    }

    private func receiveResponse(flow: ProxyFlow, clientConnection: NWConnection, targetConnection: NWConnection) {
        var responseData = Data()
        var headersComplete = false
        var contentLength: Int?
        var isChunked = false
        var headerEndIndex = 0
        print("[ProxyEngine] Setting up response receiver")

        func receiveChunk() {
            print("[ProxyEngine] Waiting for response chunk...")
            targetConnection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] content, context, isComplete, error in
                guard let self = self else { return }

                print("[ProxyEngine] Response chunk received - content: \(content?.count ?? 0) bytes, isComplete: \(isComplete), error: \(String(describing: error))")

                if let data = content {
                    responseData.append(data)
                    self.bytesReceived += data.count
                    print("[ProxyEngine] Total response so far: \(responseData.count) bytes")

                    // Try to parse headers to determine response completeness
                    if !headersComplete {
                        if let responseString = String(data: responseData, encoding: .utf8) {
                            if let headerEnd = responseString.range(of: "\r\n\r\n") {
                                headersComplete = true
                                headerEndIndex = responseString.distance(from: responseString.startIndex, to: headerEnd.upperBound)

                                // Parse Content-Length
                                let headerPart = String(responseString[..<headerEnd.lowerBound])
                                let headerLines = headerPart.lowercased().components(separatedBy: "\r\n")
                                for line in headerLines {
                                    if line.hasPrefix("content-length:") {
                                        let value = line.dropFirst("content-length:".count).trimmingCharacters(in: .whitespaces)
                                        contentLength = Int(value)
                                        print("[ProxyEngine] Content-Length: \(contentLength ?? 0)")
                                    } else if line.hasPrefix("transfer-encoding:") && line.contains("chunked") {
                                        isChunked = true
                                        print("[ProxyEngine] Transfer-Encoding: chunked")
                                    }
                                }
                            }
                        }
                    }

                    // Check if response is complete
                    var responseComplete = false
                    if headersComplete {
                        if let length = contentLength {
                            let bodyLength = responseData.count - headerEndIndex
                            if bodyLength >= length {
                                responseComplete = true
                                print("[ProxyEngine] Response complete (Content-Length match)")
                            }
                        } else if isChunked {
                            // For chunked encoding, check for the final 0\r\n\r\n
                            if let str = String(data: responseData, encoding: .utf8), str.hasSuffix("0\r\n\r\n") {
                                responseComplete = true
                                print("[ProxyEngine] Response complete (chunked)")
                            }
                        } else if contentLength == nil && !isChunked {
                            // No Content-Length and not chunked - might be a response that closes connection
                            // For now, forward what we have immediately for better UX
                            responseComplete = true
                            print("[ProxyEngine] Response complete (no Content-Length, forwarding immediately)")
                        }
                    }

                    if responseComplete || isComplete {
                        print("[ProxyEngine] Response complete, handling...")
                        self.handleResponse(flow: flow, responseData: responseData, clientConnection: clientConnection, targetConnection: targetConnection)
                        return
                    }
                }

                if let error = error {
                    print("[ProxyEngine] Error receiving response: \(error)")
                    // If we have some data, still try to forward it
                    if responseData.count > 0 {
                        self.handleResponse(flow: flow, responseData: responseData, clientConnection: clientConnection, targetConnection: targetConnection)
                    } else {
                        self.handleFlowError(flow: flow, error: error)
                    }
                    return
                }

                if isComplete {
                    print("[ProxyEngine] Connection complete, handling response...")
                    self.handleResponse(flow: flow, responseData: responseData, clientConnection: clientConnection, targetConnection: targetConnection)
                } else {
                    receiveChunk()
                }
            }
        }

        receiveChunk()
    }

    private func handleResponse(flow: ProxyFlow, responseData: Data, clientConnection: NWConnection, targetConnection: NWConnection) {
        // Parse response
        if let response = parseHTTPResponse(responseData) {
            flow.response = response
            flow.state = .completed
        } else {
            flow.state = .completed
        }

        // Notify delegate
        delegate?.proxyEngine(self, didCaptureFlow: flow.toDictionary())

        // Forward response to client
        clientConnection.send(content: responseData, completion: .contentProcessed { error in
            targetConnection.cancel()
        })
    }

    private func parseHTTPResponse(_ data: Data) -> HTTPResponse? {
        guard let responseString = String(data: data, encoding: .utf8) else {
            return nil
        }

        let lines = responseString.components(separatedBy: "\r\n")
        guard let statusLine = lines.first else {
            return nil
        }

        // Parse status line: HTTP/VERSION STATUS_CODE STATUS_MESSAGE
        let parts = statusLine.components(separatedBy: " ")
        guard parts.count >= 2 else {
            return nil
        }

        let statusCode = Int(parts[1]) ?? 0
        let statusMessage = parts.count > 2 ? parts[2...].joined(separator: " ") : ""

        // Parse headers
        var headers: [String: String] = [:]
        var headerEndIndex = 0
        for (index, line) in lines.enumerated() {
            if index == 0 { continue }
            if line.isEmpty {
                headerEndIndex = index
                break
            }
            if let colonIndex = line.firstIndex(of: ":") {
                let name = String(line[..<colonIndex]).trimmingCharacters(in: .whitespaces)
                let value = String(line[line.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                headers[name] = value
            }
        }

        // Extract body
        var body: Data?
        if headerEndIndex > 0 && headerEndIndex < lines.count - 1 {
            let bodyString = lines[(headerEndIndex + 1)...].joined(separator: "\r\n")
            body = bodyString.data(using: .utf8)
        }

        return HTTPResponse(
            statusCode: statusCode,
            statusMessage: statusMessage,
            headers: headers,
            body: body,
            timestamp: Date()
        )
    }

    private func handleFlowError(flow: ProxyFlow, error: Error) {
        flow.state = .failed
        delegate?.proxyEngine(self, didCaptureFlow: flow.toDictionary())
        delegate?.proxyEngine(self, didEncounterError: error)
    }

    // MARK: - Rules

    func setRules(_ rules: [[String: Any]]) {
        self.rules = rules
    }

    private func shouldBypass(host: String) -> Bool {
        return bypassHosts.contains(host)
    }

    private func shouldPauseForBreakpoint(request: HTTPRequest) -> Bool {
        for rule in rules {
            guard let type = rule["type"] as? String, type == "breakpoint" else {
                continue
            }

            guard let enabled = rule["isEnabled"] as? Bool, enabled else {
                continue
            }

            // Check matcher
            if let matcher = rule["matcher"] as? [String: Any] {
                if matchesRule(request: request, matcher: matcher) {
                    return true
                }
            }
        }
        return false
    }

    private func matchesRule(request: HTTPRequest, matcher: [String: Any]) -> Bool {
        // Simple URL pattern matching
        if let pattern = matcher["pattern"] as? String {
            if request.url.contains(pattern) {
                return true
            }
        }
        return false
    }

    // MARK: - Flow Control

    func pauseFlow(flowId: String) {
        if let flow = flows[flowId] {
            flow.isPaused = true
            flow.state = .paused
        }
    }

    func resumeFlow(flowId: String, modifiedRequest: [String: Any]?, modifiedResponse: [String: Any]?) {
        guard let flow = flows[flowId] else { return }

        flow.isPaused = false
        flow.continuation?.resume()
    }

    func abortFlow(flowId: String) {
        if let flow = flows[flowId] {
            flow.state = .failed
            flow.continuation?.resume(throwing: CancellationError())
            flows.removeValue(forKey: flowId)
        }
    }

    // MARK: - Throttling

    func setThrottling(downloadBytesPerSecond: Int, uploadBytesPerSecond: Int, latencyMs: Int, packetLossPercent: Double) {
        throttleDownload = downloadBytesPerSecond
        throttleUpload = uploadBytesPerSecond
        throttleLatency = latencyMs
        throttlePacketLoss = packetLossPercent
    }

    // MARK: - Status

    private func notifyStatusUpdate() {
        let status: [String: Any] = [
            "isRunning": isRunning,
            "port": port,
            "address": bindAddress,
            "activeConnections": activeConnections,
            "bytesReceived": bytesReceived,
            "bytesSent": bytesSent,
            "sslInterceptionEnabled": sslInterceptionEnabled
        ]
        delegate?.proxyEngine(self, didUpdateStatus: status)
    }
}
