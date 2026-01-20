import Foundation
import Network
import Security

/// TLS connection state
enum TLSConnectionState {
    case connecting
    case handshaking
    case connected
    case disconnected
    case error(Error)
}

/// TLS interceptor errors
enum TLSInterceptorError: Error, LocalizedError {
    case handshakeFailed
    case certificateError
    case connectionFailed
    case readFailed
    case writeFailed
    case timeout
    case sniExtractionFailed

    var errorDescription: String? {
        switch self {
        case .handshakeFailed: return "TLS handshake failed"
        case .certificateError: return "Certificate error"
        case .connectionFailed: return "Connection failed"
        case .readFailed: return "Read failed"
        case .writeFailed: return "Write failed"
        case .timeout: return "Connection timeout"
        case .sniExtractionFailed: return "Failed to extract SNI"
        }
    }
}

/// TLS interceptor delegate
protocol TLSInterceptorDelegate: AnyObject {
    func interceptor(_ interceptor: TLSInterceptor, didReceiveClientData data: Data)
    func interceptor(_ interceptor: TLSInterceptor, didReceiveServerData data: Data)
    func interceptor(_ interceptor: TLSInterceptor, didFailWithError error: Error)
    func interceptorDidClose(_ interceptor: TLSInterceptor)
}

/// TLS interceptor for MITM proxy
class TLSInterceptor {

    weak var delegate: TLSInterceptorDelegate?

    private let certificateAuthority: CertificateAuthority
    private var clientConnection: NWConnection?
    private var serverConnection: NWConnection?

    private var state: TLSConnectionState = .connecting
    private var serverHost: String
    private var serverPort: UInt16

    private let queue = DispatchQueue(label: "dev.syrah.tls-interceptor")

    /// Initialize with certificate authority and target server
    init(certificateAuthority: CertificateAuthority, serverHost: String, serverPort: UInt16) {
        self.certificateAuthority = certificateAuthority
        self.serverHost = serverHost
        self.serverPort = serverPort
    }

    // MARK: - Client Connection (from app/browser to proxy)

    /// Set up TLS server for client connection
    func acceptClientConnection(clientSocket: Int32) throws {
        // Create NWConnection from existing socket
        // For Network Extension, we'd receive NWConnection directly

        // Generate certificate for the target domain
        guard let identity = try? certificateAuthority.generateCertificate(for: serverHost) else {
            throw TLSInterceptorError.certificateError
        }

        // Create TLS parameters for server mode
        let tlsOptions = NWProtocolTLS.Options()

        // Set the server identity (our generated certificate)
        sec_protocol_options_set_local_identity(tlsOptions.securityProtocolOptions, sec_identity_create(identity)!)

        // Create TCP options
        let tcpOptions = NWProtocolTCP.Options()

        // Create parameters
        let parameters = NWParameters(tls: tlsOptions, tcp: tcpOptions)

        // Note: In actual implementation with Network Extension,
        // we would receive the connection from NEAppProxyTCPFlow
    }

    /// Handle client TLS connection (using NWConnection)
    func handleClientConnection(_ connection: NWConnection) {
        self.clientConnection = connection

        // Generate certificate for the server we're proxying to
        guard let identity = try? certificateAuthority.generateCertificate(for: serverHost) else {
            delegate?.interceptor(self, didFailWithError: TLSInterceptorError.certificateError)
            return
        }

        // Start reading from client
        readFromClient()

        // Connect to actual server
        connectToServer()
    }

    private func readFromClient() {
        clientConnection?.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }

            if let error = error {
                self.delegate?.interceptor(self, didFailWithError: error)
                return
            }

            if let data = data, !data.isEmpty {
                self.delegate?.interceptor(self, didReceiveClientData: data)
                // Forward to server
                self.sendToServer(data)
            }

            if isComplete {
                self.close()
            } else {
                self.readFromClient()
            }
        }
    }

    func sendToClient(_ data: Data) {
        clientConnection?.send(content: data, completion: .contentProcessed { [weak self] error in
            if let error = error, let self = self {
                self.delegate?.interceptor(self, didFailWithError: error)
            }
        })
    }

    // MARK: - Server Connection (from proxy to actual server)

    private func connectToServer() {
        let host = NWEndpoint.Host(serverHost)
        let port = NWEndpoint.Port(integerLiteral: serverPort)

        // Create TLS parameters for client mode
        let tlsOptions = NWProtocolTLS.Options()

        // Optionally disable certificate verification for debugging
        // In production, you'd want proper validation
        sec_protocol_options_set_verify_block(tlsOptions.securityProtocolOptions, { _, trust, complete in
            // Accept all certificates (MITM mode)
            complete(true)
        }, queue)

        let tcpOptions = NWProtocolTCP.Options()
        let parameters = NWParameters(tls: tlsOptions, tcp: tcpOptions)

        serverConnection = NWConnection(host: host, port: port, using: parameters)

        serverConnection?.stateUpdateHandler = { [weak self] state in
            guard let self = self else { return }

            switch state {
            case .ready:
                self.state = .connected
                self.readFromServer()
            case .failed(let error):
                self.delegate?.interceptor(self, didFailWithError: error)
            case .cancelled:
                self.delegate?.interceptorDidClose(self)
            default:
                break
            }
        }

        serverConnection?.start(queue: queue)
    }

    private func readFromServer() {
        serverConnection?.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }

            if let error = error {
                self.delegate?.interceptor(self, didFailWithError: error)
                return
            }

            if let data = data, !data.isEmpty {
                self.delegate?.interceptor(self, didReceiveServerData: data)
                // Forward to client
                self.sendToClient(data)
            }

            if isComplete {
                self.close()
            } else {
                self.readFromServer()
            }
        }
    }

    func sendToServer(_ data: Data) {
        serverConnection?.send(content: data, completion: .contentProcessed { [weak self] error in
            if let error = error, let self = self {
                self.delegate?.interceptor(self, didFailWithError: error)
            }
        })
    }

    // MARK: - Connection Management

    func close() {
        state = .disconnected
        clientConnection?.cancel()
        serverConnection?.cancel()
        delegate?.interceptorDidClose(self)
    }

    // MARK: - SNI Extraction

    /// Extract SNI (Server Name Indication) from TLS ClientHello
    static func extractSNI(from data: Data) -> String? {
        guard data.count > 5 else { return nil }

        // TLS Record Header
        let contentType = data[0]
        guard contentType == 0x16 else { return nil } // Handshake

        // TLS Version
        let majorVersion = data[1]
        let minorVersion = data[2]
        guard majorVersion == 3 && (minorVersion == 1 || minorVersion == 3) else { return nil }

        // Record Length
        let recordLength = Int(data[3]) << 8 | Int(data[4])
        guard data.count >= 5 + recordLength else { return nil }

        // Handshake Type
        guard data[5] == 0x01 else { return nil } // ClientHello

        // Skip to extensions
        var offset = 5 + 1 + 3 + 2 + 32 // header + type + length + version + random

        // Session ID length
        guard offset < data.count else { return nil }
        let sessionIdLength = Int(data[offset])
        offset += 1 + sessionIdLength

        // Cipher Suites length
        guard offset + 2 <= data.count else { return nil }
        let cipherSuitesLength = Int(data[offset]) << 8 | Int(data[offset + 1])
        offset += 2 + cipherSuitesLength

        // Compression Methods length
        guard offset < data.count else { return nil }
        let compressionMethodsLength = Int(data[offset])
        offset += 1 + compressionMethodsLength

        // Extensions length
        guard offset + 2 <= data.count else { return nil }
        let extensionsLength = Int(data[offset]) << 8 | Int(data[offset + 1])
        offset += 2

        let extensionsEnd = offset + extensionsLength
        guard extensionsEnd <= data.count else { return nil }

        // Parse extensions
        while offset + 4 <= extensionsEnd {
            let extensionType = Int(data[offset]) << 8 | Int(data[offset + 1])
            let extensionLength = Int(data[offset + 2]) << 8 | Int(data[offset + 3])
            offset += 4

            if extensionType == 0 { // SNI extension
                guard offset + 2 <= data.count else { return nil }
                let sniListLength = Int(data[offset]) << 8 | Int(data[offset + 1])
                offset += 2

                guard offset + sniListLength <= data.count else { return nil }

                let sniEnd = offset + sniListLength
                while offset + 3 <= sniEnd {
                    let nameType = data[offset]
                    let nameLength = Int(data[offset + 1]) << 8 | Int(data[offset + 2])
                    offset += 3

                    if nameType == 0 { // hostname
                        guard offset + nameLength <= data.count else { return nil }
                        let nameData = data[offset..<(offset + nameLength)]
                        return String(data: nameData, encoding: .utf8)
                    }

                    offset += nameLength
                }
            } else {
                offset += extensionLength
            }
        }

        return nil
    }

    /// Build a TLS ClientHello with custom SNI
    static func buildClientHello(sni: String) -> Data {
        var hello = Data()

        let sniData = sni.data(using: .utf8)!

        // Random bytes
        var random = Data(count: 32)
        _ = random.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 32, $0.baseAddress!) }

        // Build ClientHello
        var clientHello = Data()

        // Client Version (TLS 1.2)
        clientHello.append(contentsOf: [0x03, 0x03])

        // Random
        clientHello.append(random)

        // Session ID (empty)
        clientHello.append(0x00)

        // Cipher Suites
        let cipherSuites: [UInt8] = [
            0x00, 0x04, // Length
            0x00, 0x2f, // TLS_RSA_WITH_AES_128_CBC_SHA
            0x00, 0x35  // TLS_RSA_WITH_AES_256_CBC_SHA
        ]
        clientHello.append(contentsOf: cipherSuites)

        // Compression Methods
        clientHello.append(contentsOf: [0x01, 0x00]) // null compression

        // Extensions
        var extensions = Data()

        // SNI Extension
        var sniExtension = Data()
        sniExtension.append(contentsOf: [0x00, 0x00]) // Extension type (SNI)

        var sniList = Data()
        sniList.append(0x00) // name type (hostname)
        sniList.append(UInt8((sniData.count >> 8) & 0xFF))
        sniList.append(UInt8(sniData.count & 0xFF))
        sniList.append(sniData)

        let sniListLengthBytes = [UInt8((sniList.count >> 8) & 0xFF), UInt8(sniList.count & 0xFF)]

        sniExtension.append(UInt8(((sniList.count + 2) >> 8) & 0xFF))
        sniExtension.append(UInt8((sniList.count + 2) & 0xFF))
        sniExtension.append(contentsOf: sniListLengthBytes)
        sniExtension.append(sniList)

        extensions.append(sniExtension)

        // Extensions length
        clientHello.append(UInt8((extensions.count >> 8) & 0xFF))
        clientHello.append(UInt8(extensions.count & 0xFF))
        clientHello.append(extensions)

        // Handshake header
        var handshake = Data()
        handshake.append(0x01) // ClientHello
        handshake.append(UInt8((clientHello.count >> 16) & 0xFF))
        handshake.append(UInt8((clientHello.count >> 8) & 0xFF))
        handshake.append(UInt8(clientHello.count & 0xFF))
        handshake.append(clientHello)

        // TLS Record header
        hello.append(0x16) // Handshake
        hello.append(contentsOf: [0x03, 0x01]) // TLS 1.0 for compatibility
        hello.append(UInt8((handshake.count >> 8) & 0xFF))
        hello.append(UInt8(handshake.count & 0xFF))
        hello.append(handshake)

        return hello
    }
}

/// TLS connection wrapper for bidirectional interception
class TLSConnectionWrapper {

    private let clientSocket: Int32
    private let serverSocket: Int32
    private var sslContext: SSLContext?
    private let certificateAuthority: CertificateAuthority
    private let targetHost: String

    private var clientBuffer = Data()
    private var serverBuffer = Data()

    private let readQueue = DispatchQueue(label: "dev.syrah.tls.read")
    private let writeQueue = DispatchQueue(label: "dev.syrah.tls.write")

    var onClientData: ((Data) -> Void)?
    var onServerData: ((Data) -> Void)?
    var onClose: (() -> Void)?
    var onError: ((Error) -> Void)?

    init(clientSocket: Int32, serverSocket: Int32, certificateAuthority: CertificateAuthority, targetHost: String) {
        self.clientSocket = clientSocket
        self.serverSocket = serverSocket
        self.certificateAuthority = certificateAuthority
        self.targetHost = targetHost
    }

    /// Start bidirectional TLS interception
    func start() throws {
        // This would set up TLS contexts for both directions
        // Client <-> Proxy uses our generated certificate
        // Proxy <-> Server uses normal TLS client

        // For Network Extension, we'd use NWConnection which handles TLS
    }

    /// Close both connections
    func close() {
        Darwin.close(clientSocket)
        Darwin.close(serverSocket)
        onClose?()
    }
}

/// Protocol detection helper
class ProtocolDetector {

    /// Detect protocol from initial bytes
    static func detect(from data: Data) -> DetectedProtocol {
        guard !data.isEmpty else { return .unknown }

        // Check for TLS
        if data[0] == 0x16 && data.count >= 3 {
            let version = (data[1], data[2])
            if version.0 == 3 && (version.1 >= 1 && version.1 <= 4) {
                return .tls
            }
        }

        // Check for HTTP
        if data.count >= 4 {
            let prefix = String(data: data.prefix(4), encoding: .ascii)
            if prefix == "GET " || prefix == "POST" || prefix == "PUT " ||
               prefix == "HEAD" || prefix == "DELE" || prefix == "OPTI" ||
               prefix == "PATC" || prefix == "CONN" {
                return .http
            }
        }

        // Check for HTTP/2 preface
        if data.count >= 24 {
            let preface = "PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n"
            if data.prefix(24) == preface.data(using: .utf8) {
                return .http2
            }
        }

        // Check for WebSocket (after HTTP upgrade)
        // WebSocket frames start with specific opcodes

        return .unknown
    }

    enum DetectedProtocol {
        case http
        case http2
        case tls
        case websocket
        case unknown
    }
}
