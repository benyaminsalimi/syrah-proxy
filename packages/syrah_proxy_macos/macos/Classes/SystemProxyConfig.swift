import Foundation
import SystemConfiguration

/// Errors that can occur during system proxy configuration
enum SystemProxyError: Error, LocalizedError {
    case authorizationDenied
    case configurationFailed
    case networkServiceNotFound

    var errorDescription: String? {
        switch self {
        case .authorizationDenied:
            return "Authorization denied for proxy configuration"
        case .configurationFailed:
            return "Failed to configure system proxy"
        case .networkServiceNotFound:
            return "No active network service found"
        }
    }
}

/// System proxy configuration helper
class SystemProxyConfig {
    /// Enable system-wide HTTP/HTTPS proxy
    static func enableProxy(port: UInt16, address: String = "127.0.0.1") throws {
        // Use scutil or networksetup to configure system proxy
        // This requires administrator privileges

        let script = """
        #!/bin/bash
        networksetup -setwebproxy Wi-Fi \(address) \(port)
        networksetup -setsecurewebproxy Wi-Fi \(address) \(port)
        networksetup -setwebproxystate Wi-Fi on
        networksetup -setsecurewebproxystate Wi-Fi on
        """

        try executeScript(script)
    }

    /// Disable system-wide HTTP/HTTPS proxy
    static func disableProxy() throws {
        let script = """
        #!/bin/bash
        networksetup -setwebproxystate Wi-Fi off
        networksetup -setsecurewebproxystate Wi-Fi off
        """

        try executeScript(script)
    }

    /// Get current proxy settings
    static func getProxySettings() -> [String: Any]? {
        guard let proxies = SCDynamicStoreCopyProxies(nil) as? [String: Any] else {
            return nil
        }
        return proxies
    }

    /// Check if proxy is enabled
    static func isProxyEnabled() -> Bool {
        guard let settings = getProxySettings() else {
            return false
        }

        let httpEnabled = settings[kSCPropNetProxiesHTTPEnable as String] as? Int == 1
        let httpsEnabled = settings[kSCPropNetProxiesHTTPSEnable as String] as? Int == 1

        return httpEnabled || httpsEnabled
    }

    /// Get list of network services
    static func getNetworkServices() -> [String] {
        var services: [String] = []

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
        process.arguments = ["-listallnetworkservices"]

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                services = output.components(separatedBy: "\n")
                    .filter { !$0.isEmpty && !$0.hasPrefix("*") && !$0.hasPrefix("An asterisk") }
            }
        } catch {
            print("Failed to get network services: \(error)")
        }

        return services
    }

    /// Configure proxy for specific network service
    static func configureProxy(service: String, enable: Bool, address: String = "127.0.0.1", port: UInt16 = 8888) throws {
        let state = enable ? "on" : "off"

        if enable {
            let setHttpScript = """
            networksetup -setwebproxy "\(service)" \(address) \(port)
            networksetup -setsecurewebproxy "\(service)" \(address) \(port)
            """
            try executeScript(setHttpScript)
        }

        let stateScript = """
        networksetup -setwebproxystate "\(service)" \(state)
        networksetup -setsecurewebproxystate "\(service)" \(state)
        """
        try executeScript(stateScript)
    }

    /// Configure proxy for all network services
    static func configureAllServices(enable: Bool, address: String = "127.0.0.1", port: UInt16 = 8888) throws {
        let services = getNetworkServices()

        for service in services {
            do {
                try configureProxy(service: service, enable: enable, address: address, port: port)
            } catch {
                // Continue with other services
                print("Failed to configure proxy for \(service): \(error)")
            }
        }
    }

    /// Create a PAC (Proxy Auto-Config) file
    static func createPacFile(proxyAddress: String, proxyPort: UInt16, bypassHosts: [String] = []) -> String {
        var bypassConditions = bypassHosts.map { host in
            "if (shExpMatch(host, \"\(host)\")) return \"DIRECT\";"
        }.joined(separator: "\n    ")

        if bypassConditions.isEmpty {
            bypassConditions = "// No bypass hosts"
        }

        return """
        function FindProxyForURL(url, host) {
            // Bypass localhost
            if (host === "localhost" || host === "127.0.0.1") {
                return "DIRECT";
            }

            // Bypass hosts
            \(bypassConditions)

            // Use proxy for all other traffic
            return "PROXY \(proxyAddress):\(proxyPort)";
        }
        """
    }

    /// Save PAC file and configure system to use it
    static func configurePacFile(proxyAddress: String, proxyPort: UInt16, bypassHosts: [String] = []) throws -> URL {
        let pacContent = createPacFile(proxyAddress: proxyAddress, proxyPort: proxyPort, bypassHosts: bypassHosts)

        // Save to temporary file
        let tempDir = FileManager.default.temporaryDirectory
        let pacUrl = tempDir.appendingPathComponent("netscope.pac")

        try pacContent.write(to: pacUrl, atomically: true, encoding: .utf8)

        // Configure system to use PAC file
        let script = """
        networksetup -setautoproxyurl Wi-Fi "file://\(pacUrl.path)"
        networksetup -setautoproxystate Wi-Fi on
        """

        try executeScript(script)

        return pacUrl
    }

    /// Disable PAC file configuration
    static func disablePacFile() throws {
        let script = """
        networksetup -setautoproxystate Wi-Fi off
        """

        try executeScript(script)
    }

    // MARK: - Private Helpers

    private static func executeScript(_ script: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", script]

        let pipe = Pipe()
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            print("Script error: \(errorMessage)")
            throw SystemProxyError.configurationFailed
        }
    }

    /// Request authorization for proxy configuration
    static func requestAuthorization() -> Bool {
        // In production, you would use Authorization Services
        // to request admin privileges

        // For now, return true as scripts will prompt for password
        return true
    }
}

// MARK: - Network Change Observer

/// Observer for network configuration changes
class NetworkChangeObserver {
    private var store: SCDynamicStore?
    private var runLoopSource: CFRunLoopSource?
    private var callback: (() -> Void)?

    init() {
        setupObserver()
    }

    deinit {
        stopObserving()
    }

    func onNetworkChange(_ callback: @escaping () -> Void) {
        self.callback = callback
    }

    private func setupObserver() {
        var context = SCDynamicStoreContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let storeCallback: SCDynamicStoreCallBack = { (store, changedKeys, info) in
            guard let info = info else { return }
            let observer = Unmanaged<NetworkChangeObserver>.fromOpaque(info).takeUnretainedValue()
            observer.callback?()
        }

        store = SCDynamicStoreCreate(
            nil,
            "NetScope" as CFString,
            storeCallback,
            &context
        )

        guard let store = store else { return }

        let keys = [
            "State:/Network/Global/Proxies" as CFString,
            "State:/Network/Interface/.*/IPv4" as CFString
        ] as CFArray

        SCDynamicStoreSetNotificationKeys(store, nil, keys)

        runLoopSource = SCDynamicStoreCreateRunLoopSource(nil, store, 0)

        if let source = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .defaultMode)
        }
    }

    func startObserving() {
        if let source = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .defaultMode)
        }
    }

    func stopObserving() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .defaultMode)
        }
    }
}
