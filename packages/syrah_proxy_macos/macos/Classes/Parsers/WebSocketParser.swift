import Foundation

/// WebSocket frame opcode
enum WebSocketOpcode: UInt8 {
    case continuation = 0x0
    case text = 0x1
    case binary = 0x2
    case close = 0x8
    case ping = 0x9
    case pong = 0xA
    case unknown = 0xFF

    init(rawValue: UInt8) {
        switch rawValue {
        case 0x0: self = .continuation
        case 0x1: self = .text
        case 0x2: self = .binary
        case 0x8: self = .close
        case 0x9: self = .ping
        case 0xA: self = .pong
        default: self = .unknown
        }
    }
}

/// WebSocket frame
struct WebSocketFrame {
    let fin: Bool
    let opcode: WebSocketOpcode
    let masked: Bool
    let payload: Data
    let closeCode: UInt16?
    let closeReason: String?

    var isControl: Bool {
        return opcode == .close || opcode == .ping || opcode == .pong
    }

    var payloadAsString: String? {
        return String(data: payload, encoding: .utf8)
    }
}

/// WebSocket frame parser
class WebSocketParser {

    private var buffer = Data()
    private var fragmentedOpcode: WebSocketOpcode?
    private var fragmentedPayload = Data()

    /// Parse incoming data and return any complete frames
    func parse(_ data: Data) -> [WebSocketFrame] {
        buffer.append(data)

        var frames: [WebSocketFrame] = []

        while let frame = parseFrame() {
            // Handle fragmentation
            if !frame.fin && !frame.isControl {
                if frame.opcode != .continuation {
                    fragmentedOpcode = frame.opcode
                    fragmentedPayload = frame.payload
                } else {
                    fragmentedPayload.append(frame.payload)
                }
            } else if frame.opcode == .continuation && frame.fin {
                // Final fragment
                fragmentedPayload.append(frame.payload)
                if let opcode = fragmentedOpcode {
                    let completeFrame = WebSocketFrame(
                        fin: true,
                        opcode: opcode,
                        masked: frame.masked,
                        payload: fragmentedPayload,
                        closeCode: nil,
                        closeReason: nil
                    )
                    frames.append(completeFrame)
                }
                fragmentedOpcode = nil
                fragmentedPayload.removeAll()
            } else {
                frames.append(frame)
            }
        }

        return frames
    }

    private func parseFrame() -> WebSocketFrame? {
        // Need at least 2 bytes for header
        guard buffer.count >= 2 else { return nil }

        let byte0 = buffer[0]
        let byte1 = buffer[1]

        let fin = (byte0 & 0x80) != 0
        let opcode = WebSocketOpcode(rawValue: byte0 & 0x0F)
        let masked = (byte1 & 0x80) != 0
        var payloadLength = UInt64(byte1 & 0x7F)

        var offset = 2

        // Extended payload length
        if payloadLength == 126 {
            guard buffer.count >= 4 else { return nil }
            payloadLength = UInt64(buffer[2]) << 8 | UInt64(buffer[3])
            offset = 4
        } else if payloadLength == 127 {
            guard buffer.count >= 10 else { return nil }
            payloadLength = 0
            for i in 0..<8 {
                payloadLength = payloadLength << 8 | UInt64(buffer[2 + i])
            }
            offset = 10
        }

        // Masking key
        var maskingKey: [UInt8]?
        if masked {
            guard buffer.count >= offset + 4 else { return nil }
            maskingKey = [buffer[offset], buffer[offset + 1], buffer[offset + 2], buffer[offset + 3]]
            offset += 4
        }

        // Payload
        let totalLength = offset + Int(payloadLength)
        guard buffer.count >= totalLength else { return nil }

        var payload = Data(buffer[offset..<totalLength])

        // Unmask if needed
        if let key = maskingKey {
            payload = unmask(payload, key: key)
        }

        // Remove parsed data from buffer
        buffer.removeFirst(totalLength)

        // Parse close frame
        var closeCode: UInt16?
        var closeReason: String?
        if opcode == .close && payload.count >= 2 {
            closeCode = UInt16(payload[0]) << 8 | UInt16(payload[1])
            if payload.count > 2 {
                closeReason = String(data: payload[2...], encoding: .utf8)
            }
        }

        return WebSocketFrame(
            fin: fin,
            opcode: opcode,
            masked: masked,
            payload: payload,
            closeCode: closeCode,
            closeReason: closeReason
        )
    }

    private func unmask(_ data: Data, key: [UInt8]) -> Data {
        var unmasked = Data(count: data.count)
        for i in 0..<data.count {
            unmasked[i] = data[i] ^ key[i % 4]
        }
        return unmasked
    }

    /// Reset parser state
    func reset() {
        buffer.removeAll()
        fragmentedOpcode = nil
        fragmentedPayload.removeAll()
    }
}

/// WebSocket frame builder
class WebSocketFrameBuilder {

    /// Build a WebSocket frame
    static func buildFrame(
        opcode: WebSocketOpcode,
        payload: Data,
        fin: Bool = true,
        mask: Bool = false
    ) -> Data {
        var frame = Data()

        // First byte: FIN + opcode
        var byte0: UInt8 = opcode.rawValue
        if fin {
            byte0 |= 0x80
        }
        frame.append(byte0)

        // Second byte: MASK + payload length
        var byte1: UInt8 = mask ? 0x80 : 0x00

        if payload.count < 126 {
            byte1 |= UInt8(payload.count)
            frame.append(byte1)
        } else if payload.count < 65536 {
            byte1 |= 126
            frame.append(byte1)
            frame.append(UInt8((payload.count >> 8) & 0xFF))
            frame.append(UInt8(payload.count & 0xFF))
        } else {
            byte1 |= 127
            frame.append(byte1)
            for i in (0..<8).reversed() {
                frame.append(UInt8((payload.count >> (i * 8)) & 0xFF))
            }
        }

        // Masking key (if masked)
        if mask {
            let maskingKey: [UInt8] = [
                UInt8.random(in: 0...255),
                UInt8.random(in: 0...255),
                UInt8.random(in: 0...255),
                UInt8.random(in: 0...255)
            ]
            frame.append(contentsOf: maskingKey)

            // Mask payload
            for i in 0..<payload.count {
                frame.append(payload[i] ^ maskingKey[i % 4])
            }
        } else {
            frame.append(payload)
        }

        return frame
    }

    /// Build a text frame
    static func textFrame(_ text: String, mask: Bool = false) -> Data {
        let payload = text.data(using: .utf8) ?? Data()
        return buildFrame(opcode: .text, payload: payload, mask: mask)
    }

    /// Build a binary frame
    static func binaryFrame(_ data: Data, mask: Bool = false) -> Data {
        return buildFrame(opcode: .binary, payload: data, mask: mask)
    }

    /// Build a close frame
    static func closeFrame(code: UInt16 = 1000, reason: String? = nil, mask: Bool = false) -> Data {
        var payload = Data()
        payload.append(UInt8((code >> 8) & 0xFF))
        payload.append(UInt8(code & 0xFF))
        if let reason = reason, let reasonData = reason.data(using: .utf8) {
            payload.append(reasonData)
        }
        return buildFrame(opcode: .close, payload: payload, mask: mask)
    }

    /// Build a ping frame
    static func pingFrame(_ data: Data = Data(), mask: Bool = false) -> Data {
        return buildFrame(opcode: .ping, payload: data, mask: mask)
    }

    /// Build a pong frame
    static func pongFrame(_ data: Data = Data(), mask: Bool = false) -> Data {
        return buildFrame(opcode: .pong, payload: data, mask: mask)
    }
}

/// WebSocket handshake helper
class WebSocketHandshake {

    private static let webSocketGUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"

    /// Check if an HTTP request is a WebSocket upgrade request
    static func isUpgradeRequest(_ request: ParsedHTTPRequest) -> Bool {
        let upgrade = request.headers["Upgrade"] ?? request.headers["upgrade"] ?? ""
        let connection = request.headers["Connection"] ?? request.headers["connection"] ?? ""
        return upgrade.lowercased() == "websocket" && connection.lowercased().contains("upgrade")
    }

    /// Get WebSocket key from request
    static func getWebSocketKey(_ request: ParsedHTTPRequest) -> String? {
        return request.headers["Sec-WebSocket-Key"] ?? request.headers["sec-websocket-key"]
    }

    /// Generate WebSocket accept key from client key
    static func generateAcceptKey(clientKey: String) -> String {
        let combined = clientKey + webSocketGUID
        guard let data = combined.data(using: .utf8) else { return "" }

        // SHA-1 hash
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA1($0.baseAddress, CC_LONG(data.count), &digest)
        }

        // Base64 encode
        return Data(digest).base64EncodedString()
    }

    /// Build WebSocket upgrade response
    static func buildUpgradeResponse(clientKey: String, protocols: [String]? = nil) -> Data {
        let acceptKey = generateAcceptKey(clientKey: clientKey)

        var headers: [String: String] = [
            "Upgrade": "websocket",
            "Connection": "Upgrade",
            "Sec-WebSocket-Accept": acceptKey
        ]

        if let protocols = protocols, !protocols.isEmpty {
            headers["Sec-WebSocket-Protocol"] = protocols.first
        }

        return HTTPMessageBuilder.buildResponse(
            statusCode: 101,
            statusMessage: "Switching Protocols",
            headers: headers
        )
    }
}

// Import CommonCrypto for SHA-1
import CommonCrypto
