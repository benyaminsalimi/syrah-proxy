import Cocoa
import FlutterMacOS
import Network
import Security

public class SyrahProxyMacosPlugin: NSObject, FlutterPlugin {
    private var methodChannel: FlutterMethodChannel?
    private var flowEventChannel: FlutterEventChannel?
    private var statusEventChannel: FlutterEventChannel?

    private var flowEventSink: FlutterEventSink?
    private var statusEventSink: FlutterEventSink?

    private var proxyEngine: ProxyEngine?
    private var certificateAuthority: CertificateAuthority?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = SyrahProxyMacosPlugin()

        // Method channel
        let methodChannel = FlutterMethodChannel(
            name: "dev.syrah.proxy.macos/methods",
            binaryMessenger: registrar.messenger
        )
        instance.methodChannel = methodChannel
        registrar.addMethodCallDelegate(instance, channel: methodChannel)

        // Flow event channel
        let flowEventChannel = FlutterEventChannel(
            name: "dev.syrah.proxy.macos/flows",
            binaryMessenger: registrar.messenger
        )
        instance.flowEventChannel = flowEventChannel
        flowEventChannel.setStreamHandler(FlowStreamHandler(plugin: instance))

        // Status event channel
        let statusEventChannel = FlutterEventChannel(
            name: "dev.syrah.proxy.macos/status",
            binaryMessenger: registrar.messenger
        )
        instance.statusEventChannel = statusEventChannel
        statusEventChannel.setStreamHandler(StatusStreamHandler(plugin: instance))
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any]

        switch call.method {
        case "getPlatformVersion":
            result("macOS " + ProcessInfo.processInfo.operatingSystemVersionString)

        case "initialize":
            initialize(result: result)

        case "startProxy":
            let port = args?["port"] as? Int ?? 8888
            let bindAddress = args?["bindAddress"] as? String ?? "127.0.0.1"
            let enableSsl = args?["enableSslInterception"] as? Bool ?? true
            let bypass = args?["bypassHosts"] as? [String] ?? []
            startProxy(port: port, bindAddress: bindAddress, enableSsl: enableSsl, bypassHosts: bypass, result: result)

        case "stopProxy":
            stopProxy(result: result)

        case "getProxyStatus":
            getProxyStatus(result: result)

        case "getRootCertificate":
            getRootCertificate(result: result)

        case "exportRootCertificate":
            let format = args?["format"] as? String ?? "pem"
            exportRootCertificate(format: format, result: result)

        case "installRootCertificate":
            installRootCertificate(result: result)

        case "isRootCertificateTrusted":
            isRootCertificateTrusted(result: result)

        case "setRules":
            let rules = args?["rules"] as? [[String: Any]] ?? []
            setRules(rules: rules, result: result)

        case "pauseFlow":
            let flowId = args?["flowId"] as? String ?? ""
            pauseFlow(flowId: flowId, result: result)

        case "resumeFlow":
            let flowId = args?["flowId"] as? String ?? ""
            let modRequest = args?["modifiedRequest"] as? [String: Any]
            let modResponse = args?["modifiedResponse"] as? [String: Any]
            resumeFlow(flowId: flowId, modifiedRequest: modRequest, modifiedResponse: modResponse, result: result)

        case "abortFlow":
            let flowId = args?["flowId"] as? String ?? ""
            abortFlow(flowId: flowId, result: result)

        case "setThrottling":
            let download = args?["downloadBytesPerSecond"] as? Int ?? 0
            let upload = args?["uploadBytesPerSecond"] as? Int ?? 0
            let latency = args?["latencyMs"] as? Int ?? 0
            let packetLoss = args?["packetLossPercent"] as? Double ?? 0
            setThrottling(download: download, upload: upload, latency: latency, packetLoss: packetLoss, result: result)

        case "configureSystemProxy":
            let enable = args?["enable"] as? Bool ?? false
            configureSystemProxy(enable: enable, result: result)

        case "installNetworkExtension":
            installNetworkExtension(result: result)

        case "isNetworkExtensionInstalled":
            isNetworkExtensionInstalled(result: result)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Implementation Methods

    private func initialize(result: @escaping FlutterResult) {
        print("[SyrahProxy] Initializing...")
        do {
            // Initialize certificate authority
            print("[SyrahProxy] Creating CertificateAuthority...")
            certificateAuthority = try CertificateAuthority()
            print("[SyrahProxy] CertificateAuthority created successfully")

            // Initialize proxy engine
            print("[SyrahProxy] Creating ProxyEngine...")
            proxyEngine = ProxyEngine(certificateAuthority: certificateAuthority!)
            proxyEngine?.delegate = self
            print("[SyrahProxy] ProxyEngine created, delegate set")

            result(true)
            print("[SyrahProxy] Initialization complete")
        } catch {
            print("[SyrahProxy] Initialization error: \(error)")
            result(FlutterError(code: "INIT_ERROR", message: error.localizedDescription, details: nil))
        }
    }

    private func startProxy(port: Int, bindAddress: String, enableSsl: Bool, bypassHosts: [String], result: @escaping FlutterResult) {
        print("[SyrahProxy] startProxy called - port: \(port), bindAddress: \(bindAddress), enableSsl: \(enableSsl)")

        guard let engine = proxyEngine else {
            print("[SyrahProxy] Error: Proxy engine not initialized")
            result(FlutterError(code: "NOT_INITIALIZED", message: "Proxy not initialized", details: nil))
            return
        }

        do {
            print("[SyrahProxy] Starting proxy engine...")
            try engine.start(
                port: UInt16(port),
                bindAddress: bindAddress,
                enableSslInterception: enableSsl,
                bypassHosts: bypassHosts
            )
            print("[SyrahProxy] Proxy started successfully on \(bindAddress):\(port)")
            result(true)
        } catch {
            print("[SyrahProxy] Failed to start proxy: \(error)")
            result(FlutterError(code: "START_ERROR", message: error.localizedDescription, details: nil))
        }
    }

    private func stopProxy(result: @escaping FlutterResult) {
        proxyEngine?.stop()
        result(true)
    }

    private func getProxyStatus(result: @escaping FlutterResult) {
        guard let engine = proxyEngine else {
            result(["isRunning": false])
            return
        }

        result([
            "isRunning": engine.isRunning,
            "port": engine.port,
            "address": engine.bindAddress,
            "activeConnections": engine.activeConnections,
            "bytesReceived": engine.bytesReceived,
            "bytesSent": engine.bytesSent,
            "sslInterceptionEnabled": engine.sslInterceptionEnabled
        ])
    }

    private func getRootCertificate(result: @escaping FlutterResult) {
        guard let ca = certificateAuthority else {
            result(FlutterError(code: "NOT_INITIALIZED", message: "Certificate authority not initialized", details: nil))
            return
        }

        result([
            "subject": ca.rootCertificateSubject,
            "issuer": ca.rootCertificateIssuer,
            "serialNumber": ca.rootCertificateSerialNumber,
            "notBefore": ca.rootCertificateNotBefore.timeIntervalSince1970,
            "notAfter": ca.rootCertificateNotAfter.timeIntervalSince1970,
            "fingerprint": ca.rootCertificateFingerprint,
            "isCA": true,
            "isRootCA": true
        ])
    }

    private func exportRootCertificate(format: String, result: @escaping FlutterResult) {
        guard let ca = certificateAuthority else {
            result(FlutterError(code: "NOT_INITIALIZED", message: "Certificate authority not initialized", details: nil))
            return
        }

        do {
            let data: Data
            switch format.lowercased() {
            case "pem":
                data = try ca.exportRootCertificate(format: .pem)
            case "der":
                data = try ca.exportRootCertificate(format: .der)
            case "p12", "pkcs12":
                data = try ca.exportRootCertificate(format: .pkcs12)
            default:
                data = try ca.exportRootCertificate(format: .pem)
            }
            result(FlutterStandardTypedData(bytes: data))
        } catch {
            result(FlutterError(code: "EXPORT_ERROR", message: error.localizedDescription, details: nil))
        }
    }

    private func installRootCertificate(result: @escaping FlutterResult) {
        guard let ca = certificateAuthority else {
            result(FlutterError(code: "NOT_INITIALIZED", message: "Certificate authority not initialized", details: nil))
            return
        }

        do {
            try ca.installRootCertificate()
            result(true)
        } catch {
            result(FlutterError(code: "INSTALL_ERROR", message: error.localizedDescription, details: nil))
        }
    }

    private func isRootCertificateTrusted(result: @escaping FlutterResult) {
        guard let ca = certificateAuthority else {
            result(false)
            return
        }

        result(ca.isRootCertificateTrusted())
    }

    private func setRules(rules: [[String: Any]], result: @escaping FlutterResult) {
        proxyEngine?.setRules(rules)
        result(true)
    }

    private func pauseFlow(flowId: String, result: @escaping FlutterResult) {
        proxyEngine?.pauseFlow(flowId: flowId)
        result(true)
    }

    private func resumeFlow(flowId: String, modifiedRequest: [String: Any]?, modifiedResponse: [String: Any]?, result: @escaping FlutterResult) {
        proxyEngine?.resumeFlow(flowId: flowId, modifiedRequest: modifiedRequest, modifiedResponse: modifiedResponse)
        result(true)
    }

    private func abortFlow(flowId: String, result: @escaping FlutterResult) {
        proxyEngine?.abortFlow(flowId: flowId)
        result(true)
    }

    private func setThrottling(download: Int, upload: Int, latency: Int, packetLoss: Double, result: @escaping FlutterResult) {
        proxyEngine?.setThrottling(
            downloadBytesPerSecond: download,
            uploadBytesPerSecond: upload,
            latencyMs: latency,
            packetLossPercent: packetLoss
        )
        result(true)
    }

    private func configureSystemProxy(enable: Bool, result: @escaping FlutterResult) {
        do {
            if enable {
                try SystemProxyConfig.enableProxy(port: proxyEngine?.port ?? 8888)
            } else {
                try SystemProxyConfig.disableProxy()
            }
            result(true)
        } catch {
            result(FlutterError(code: "PROXY_CONFIG_ERROR", message: error.localizedDescription, details: nil))
        }
    }

    private func installNetworkExtension(result: @escaping FlutterResult) {
        // Network extension installation requires additional setup
        // This is a placeholder for the actual implementation
        result(FlutterError(code: "NOT_IMPLEMENTED", message: "Network extension not yet implemented", details: nil))
    }

    private func isNetworkExtensionInstalled(result: @escaping FlutterResult) {
        result(false)
    }

    // MARK: - Event Sinks

    func setFlowEventSink(_ sink: FlutterEventSink?) {
        flowEventSink = sink
    }

    func setStatusEventSink(_ sink: FlutterEventSink?) {
        statusEventSink = sink
    }
}

// MARK: - ProxyEngineDelegate

extension SyrahProxyMacosPlugin: ProxyEngineDelegate {
    func proxyEngine(_ engine: ProxyEngine, didCaptureFlow flow: [String: Any]) {
        DispatchQueue.main.async {
            self.flowEventSink?(flow)
        }
    }

    func proxyEngine(_ engine: ProxyEngine, didUpdateStatus status: [String: Any]) {
        DispatchQueue.main.async {
            self.statusEventSink?(status)
        }
    }

    func proxyEngine(_ engine: ProxyEngine, didEncounterError error: Error) {
        DispatchQueue.main.async {
            self.statusEventSink?(["error": error.localizedDescription])
        }
    }
}

// MARK: - Stream Handlers

class FlowStreamHandler: NSObject, FlutterStreamHandler {
    weak var plugin: SyrahProxyMacosPlugin?

    init(plugin: SyrahProxyMacosPlugin) {
        self.plugin = plugin
    }

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        plugin?.setFlowEventSink(events)
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        plugin?.setFlowEventSink(nil)
        return nil
    }
}

class StatusStreamHandler: NSObject, FlutterStreamHandler {
    weak var plugin: SyrahProxyMacosPlugin?

    init(plugin: SyrahProxyMacosPlugin) {
        self.plugin = plugin
    }

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        plugin?.setStatusEventSink(events)
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        plugin?.setStatusEventSink(nil)
        return nil
    }
}
