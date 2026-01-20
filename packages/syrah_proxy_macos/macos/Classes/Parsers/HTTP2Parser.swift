import Foundation

/// HTTP/2 Frame Types
enum HTTP2FrameType: UInt8 {
    case data = 0x0
    case headers = 0x1
    case priority = 0x2
    case rstStream = 0x3
    case settings = 0x4
    case pushPromise = 0x5
    case ping = 0x6
    case goaway = 0x7
    case windowUpdate = 0x8
    case continuation = 0x9
    case unknown = 0xFF

    init(rawValue: UInt8) {
        switch rawValue {
        case 0x0: self = .data
        case 0x1: self = .headers
        case 0x2: self = .priority
        case 0x3: self = .rstStream
        case 0x4: self = .settings
        case 0x5: self = .pushPromise
        case 0x6: self = .ping
        case 0x7: self = .goaway
        case 0x8: self = .windowUpdate
        case 0x9: self = .continuation
        default: self = .unknown
        }
    }
}

/// HTTP/2 Frame Flags
struct HTTP2FrameFlags: OptionSet {
    let rawValue: UInt8

    static let endStream = HTTP2FrameFlags(rawValue: 0x1)
    static let endHeaders = HTTP2FrameFlags(rawValue: 0x4)
    static let padded = HTTP2FrameFlags(rawValue: 0x8)
    static let priority = HTTP2FrameFlags(rawValue: 0x20)
}

/// HTTP/2 Frame
struct HTTP2Frame {
    let length: UInt32
    let type: HTTP2FrameType
    let flags: HTTP2FrameFlags
    let streamId: UInt32
    let payload: Data
}

/// HTTP/2 Settings
struct HTTP2Settings {
    var headerTableSize: UInt32 = 4096
    var enablePush: Bool = true
    var maxConcurrentStreams: UInt32 = 100
    var initialWindowSize: UInt32 = 65535
    var maxFrameSize: UInt32 = 16384
    var maxHeaderListSize: UInt32 = UInt32.max
}

/// HTTP/2 Stream State
enum HTTP2StreamState {
    case idle
    case reservedLocal
    case reservedRemote
    case open
    case halfClosedLocal
    case halfClosedRemote
    case closed
}

/// HTTP/2 Stream
class HTTP2Stream {
    let streamId: UInt32
    var state: HTTP2StreamState = .idle
    var requestHeaders: [(String, String)] = []
    var responseHeaders: [(String, String)] = []
    var requestData = Data()
    var responseData = Data()
    var windowSize: Int32 = 65535

    init(streamId: UInt32) {
        self.streamId = streamId
    }
}

/// HPACK Static Table
class HPACKStaticTable {
    static let entries: [(String, String?)] = [
        (":authority", nil),
        (":method", "GET"),
        (":method", "POST"),
        (":path", "/"),
        (":path", "/index.html"),
        (":scheme", "http"),
        (":scheme", "https"),
        (":status", "200"),
        (":status", "204"),
        (":status", "206"),
        (":status", "304"),
        (":status", "400"),
        (":status", "404"),
        (":status", "500"),
        ("accept-charset", nil),
        ("accept-encoding", "gzip, deflate"),
        ("accept-language", nil),
        ("accept-ranges", nil),
        ("accept", nil),
        ("access-control-allow-origin", nil),
        ("age", nil),
        ("allow", nil),
        ("authorization", nil),
        ("cache-control", nil),
        ("content-disposition", nil),
        ("content-encoding", nil),
        ("content-language", nil),
        ("content-length", nil),
        ("content-location", nil),
        ("content-range", nil),
        ("content-type", nil),
        ("cookie", nil),
        ("date", nil),
        ("etag", nil),
        ("expect", nil),
        ("expires", nil),
        ("from", nil),
        ("host", nil),
        ("if-match", nil),
        ("if-modified-since", nil),
        ("if-none-match", nil),
        ("if-range", nil),
        ("if-unmodified-since", nil),
        ("last-modified", nil),
        ("link", nil),
        ("location", nil),
        ("max-forwards", nil),
        ("proxy-authenticate", nil),
        ("proxy-authorization", nil),
        ("range", nil),
        ("referer", nil),
        ("refresh", nil),
        ("retry-after", nil),
        ("server", nil),
        ("set-cookie", nil),
        ("strict-transport-security", nil),
        ("transfer-encoding", nil),
        ("user-agent", nil),
        ("vary", nil),
        ("via", nil),
        ("www-authenticate", nil)
    ]

    static func get(index: Int) -> (String, String?)? {
        guard index > 0 && index <= entries.count else { return nil }
        return entries[index - 1]
    }
}

/// HPACK Dynamic Table
class HPACKDynamicTable {
    private var entries: [(String, String)] = []
    private var maxSize: Int = 4096
    private var currentSize: Int = 0

    func add(name: String, value: String) {
        let entrySize = name.count + value.count + 32

        // Evict entries if needed
        while currentSize + entrySize > maxSize && !entries.isEmpty {
            let removed = entries.removeLast()
            currentSize -= removed.0.count + removed.1.count + 32
        }

        if entrySize <= maxSize {
            entries.insert((name, value), at: 0)
            currentSize += entrySize
        }
    }

    func get(index: Int) -> (String, String)? {
        let adjustedIndex = index - HPACKStaticTable.entries.count - 1
        guard adjustedIndex >= 0 && adjustedIndex < entries.count else { return nil }
        return entries[adjustedIndex]
    }

    func setMaxSize(_ size: Int) {
        maxSize = size
        while currentSize > maxSize && !entries.isEmpty {
            let removed = entries.removeLast()
            currentSize -= removed.0.count + removed.1.count + 32
        }
    }
}

/// HPACK Decoder
class HPACKDecoder {
    private let dynamicTable = HPACKDynamicTable()

    func decode(_ data: Data) -> [(String, String)]? {
        var headers: [(String, String)] = []
        var offset = 0

        while offset < data.count {
            let byte = data[offset]

            if byte & 0x80 != 0 {
                // Indexed Header Field
                guard let (index, newOffset) = decodeInteger(data, offset: offset, prefixBits: 7) else {
                    return nil
                }
                offset = newOffset

                if let entry = getEntry(index: Int(index)) {
                    headers.append(entry)
                }
            } else if byte & 0x40 != 0 {
                // Literal Header Field with Incremental Indexing
                guard let (name, value, newOffset) = decodeLiteralHeader(data, offset: offset, prefixBits: 6) else {
                    return nil
                }
                offset = newOffset
                headers.append((name, value))
                dynamicTable.add(name: name, value: value)
            } else if byte & 0x20 != 0 {
                // Dynamic Table Size Update
                guard let (size, newOffset) = decodeInteger(data, offset: offset, prefixBits: 5) else {
                    return nil
                }
                offset = newOffset
                dynamicTable.setMaxSize(Int(size))
            } else {
                // Literal Header Field without Indexing or Never Indexed
                let prefixBits = (byte & 0x10 != 0) ? 4 : 4
                guard let (name, value, newOffset) = decodeLiteralHeader(data, offset: offset, prefixBits: prefixBits) else {
                    return nil
                }
                offset = newOffset
                headers.append((name, value))
            }
        }

        return headers
    }

    private func getEntry(index: Int) -> (String, String)? {
        if index <= HPACKStaticTable.entries.count {
            if let entry = HPACKStaticTable.get(index: index) {
                return (entry.0, entry.1 ?? "")
            }
        } else {
            return dynamicTable.get(index: index)
        }
        return nil
    }

    private func decodeInteger(_ data: Data, offset: Int, prefixBits: Int) -> (UInt64, Int)? {
        guard offset < data.count else { return nil }

        let prefixMask = UInt8((1 << prefixBits) - 1)
        var value = UInt64(data[offset] & prefixMask)
        var currentOffset = offset + 1

        if value == UInt64(prefixMask) {
            var m: UInt64 = 0
            repeat {
                guard currentOffset < data.count else { return nil }
                let byte = data[currentOffset]
                value += UInt64(byte & 0x7F) << m
                m += 7
                currentOffset += 1
            } while data[currentOffset - 1] & 0x80 != 0
        }

        return (value, currentOffset)
    }

    private func decodeLiteralHeader(_ data: Data, offset: Int, prefixBits: Int) -> (String, String, Int)? {
        guard let (index, nameOffset) = decodeInteger(data, offset: offset, prefixBits: prefixBits) else {
            return nil
        }

        var name: String
        var valueOffset: Int

        if index == 0 {
            // New name
            guard let (decodedName, newOffset) = decodeString(data, offset: nameOffset) else {
                return nil
            }
            name = decodedName
            valueOffset = newOffset
        } else {
            // Indexed name
            if let entry = getEntry(index: Int(index)) {
                name = entry.0
            } else {
                return nil
            }
            valueOffset = nameOffset
        }

        guard let (value, finalOffset) = decodeString(data, offset: valueOffset) else {
            return nil
        }

        return (name, value, finalOffset)
    }

    private func decodeString(_ data: Data, offset: Int) -> (String, Int)? {
        guard offset < data.count else { return nil }

        let huffmanEncoded = (data[offset] & 0x80) != 0
        guard let (length, stringOffset) = decodeInteger(data, offset: offset, prefixBits: 7) else {
            return nil
        }

        let endOffset = stringOffset + Int(length)
        guard endOffset <= data.count else { return nil }

        let stringData = data[stringOffset..<endOffset]

        let result: String?
        if huffmanEncoded {
            result = HPACKHuffman.decode(Data(stringData))
        } else {
            result = String(data: stringData, encoding: .utf8)
        }

        guard let decodedString = result else { return nil }
        return (decodedString, endOffset)
    }
}

/// HPACK Encoder
class HPACKEncoder {
    private let dynamicTable = HPACKDynamicTable()

    func encode(_ headers: [(String, String)]) -> Data {
        var data = Data()

        for (name, value) in headers {
            // Simple encoding: literal without indexing
            data.append(0x00) // Literal without indexing, new name

            // Encode name
            let nameData = name.data(using: .utf8) ?? Data()
            data.append(contentsOf: encodeInteger(UInt64(nameData.count), prefixBits: 7, prefixByte: 0x00))
            data.append(nameData)

            // Encode value
            let valueData = value.data(using: .utf8) ?? Data()
            data.append(contentsOf: encodeInteger(UInt64(valueData.count), prefixBits: 7, prefixByte: 0x00))
            data.append(valueData)
        }

        return data
    }

    private func encodeInteger(_ value: UInt64, prefixBits: Int, prefixByte: UInt8) -> [UInt8] {
        let prefixMask = UInt8((1 << prefixBits) - 1)

        if value < UInt64(prefixMask) {
            return [prefixByte | UInt8(value)]
        }

        var bytes: [UInt8] = [prefixByte | prefixMask]
        var remaining = value - UInt64(prefixMask)

        while remaining >= 128 {
            bytes.append(UInt8(remaining & 0x7F) | 0x80)
            remaining >>= 7
        }
        bytes.append(UInt8(remaining))

        return bytes
    }
}

/// Simplified Huffman decoder for HPACK
class HPACKHuffman {
    // Huffman decoding table (simplified - full implementation would include complete table)
    static func decode(_ data: Data) -> String? {
        // Simplified: For now, treat as non-Huffman encoded
        // Full implementation would require complete Huffman tree
        return String(data: data, encoding: .utf8)
    }
}

/// HTTP/2 Frame Parser
class HTTP2Parser {
    private var buffer = Data()
    private var streams: [UInt32: HTTP2Stream] = [:]
    private var localSettings = HTTP2Settings()
    private var remoteSettings = HTTP2Settings()
    private let hpackDecoder = HPACKDecoder()
    private let hpackEncoder = HPACKEncoder()

    /// Connection preface
    static let connectionPreface = "PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n".data(using: .utf8)!

    /// Parse incoming data and return any complete frames
    func parse(_ data: Data) -> [HTTP2Frame] {
        buffer.append(data)

        var frames: [HTTP2Frame] = []

        while let frame = parseFrame() {
            frames.append(frame)
            processFrame(frame)
        }

        return frames
    }

    private func parseFrame() -> HTTP2Frame? {
        // Frame header is 9 bytes
        guard buffer.count >= 9 else { return nil }

        // Length (24 bits)
        let length = UInt32(buffer[0]) << 16 | UInt32(buffer[1]) << 8 | UInt32(buffer[2])

        // Type (8 bits)
        let type = HTTP2FrameType(rawValue: buffer[3])

        // Flags (8 bits)
        let flags = HTTP2FrameFlags(rawValue: buffer[4])

        // Stream ID (31 bits, ignore reserved bit)
        let streamId = (UInt32(buffer[5]) & 0x7F) << 24 |
                       UInt32(buffer[6]) << 16 |
                       UInt32(buffer[7]) << 8 |
                       UInt32(buffer[8])

        // Check if we have complete frame
        let totalLength = 9 + Int(length)
        guard buffer.count >= totalLength else { return nil }

        // Extract payload
        let payload = Data(buffer[9..<totalLength])

        // Remove parsed data from buffer
        buffer.removeFirst(totalLength)

        return HTTP2Frame(
            length: length,
            type: type,
            flags: flags,
            streamId: streamId,
            payload: payload
        )
    }

    private func processFrame(_ frame: HTTP2Frame) {
        switch frame.type {
        case .headers:
            processHeadersFrame(frame)
        case .data:
            processDataFrame(frame)
        case .settings:
            processSettingsFrame(frame)
        case .windowUpdate:
            processWindowUpdateFrame(frame)
        case .rstStream:
            processRstStreamFrame(frame)
        case .goaway:
            processGoawayFrame(frame)
        default:
            break
        }
    }

    private func processHeadersFrame(_ frame: HTTP2Frame) {
        var payload = frame.payload
        var offset = 0

        // Handle padding
        if frame.flags.contains(.padded) {
            let padLength = Int(payload[0])
            offset = 1
            payload = payload.dropLast(padLength)
        }

        // Handle priority
        if frame.flags.contains(.priority) {
            offset += 5 // Skip priority fields
        }

        let headerBlock = Data(payload[offset...])

        if let headers = hpackDecoder.decode(headerBlock) {
            let stream = getOrCreateStream(frame.streamId)

            // Determine if request or response based on pseudo-headers
            let isRequest = headers.contains { $0.0 == ":method" }

            if isRequest {
                stream.requestHeaders = headers
            } else {
                stream.responseHeaders = headers
            }

            if frame.flags.contains(.endHeaders) {
                stream.state = frame.flags.contains(.endStream) ? .halfClosedRemote : .open
            }
        }
    }

    private func processDataFrame(_ frame: HTTP2Frame) {
        guard let stream = streams[frame.streamId] else { return }

        var payload = frame.payload

        // Handle padding
        if frame.flags.contains(.padded) {
            let padLength = Int(payload[0])
            payload = Data(payload[1..<(payload.count - padLength)])
        }

        // Append to appropriate buffer
        if stream.state == .open || stream.state == .halfClosedLocal {
            stream.responseData.append(payload)
        } else {
            stream.requestData.append(payload)
        }

        if frame.flags.contains(.endStream) {
            if stream.state == .open {
                stream.state = .halfClosedRemote
            } else if stream.state == .halfClosedLocal {
                stream.state = .closed
            }
        }
    }

    private func processSettingsFrame(_ frame: HTTP2Frame) {
        guard frame.streamId == 0 else { return }

        // ACK frame
        if frame.flags.rawValue & 0x1 != 0 {
            return
        }

        // Parse settings
        var offset = 0
        while offset + 6 <= frame.payload.count {
            let identifier = UInt16(frame.payload[offset]) << 8 | UInt16(frame.payload[offset + 1])
            let value = UInt32(frame.payload[offset + 2]) << 24 |
                        UInt32(frame.payload[offset + 3]) << 16 |
                        UInt32(frame.payload[offset + 4]) << 8 |
                        UInt32(frame.payload[offset + 5])

            switch identifier {
            case 0x1: remoteSettings.headerTableSize = value
            case 0x2: remoteSettings.enablePush = value != 0
            case 0x3: remoteSettings.maxConcurrentStreams = value
            case 0x4: remoteSettings.initialWindowSize = value
            case 0x5: remoteSettings.maxFrameSize = value
            case 0x6: remoteSettings.maxHeaderListSize = value
            default: break
            }

            offset += 6
        }
    }

    private func processWindowUpdateFrame(_ frame: HTTP2Frame) {
        guard frame.payload.count >= 4 else { return }

        let increment = Int32(frame.payload[0] & 0x7F) << 24 |
                        Int32(frame.payload[1]) << 16 |
                        Int32(frame.payload[2]) << 8 |
                        Int32(frame.payload[3])

        if frame.streamId == 0 {
            // Connection-level window update
        } else if let stream = streams[frame.streamId] {
            stream.windowSize += increment
        }
    }

    private func processRstStreamFrame(_ frame: HTTP2Frame) {
        if let stream = streams[frame.streamId] {
            stream.state = .closed
        }
    }

    private func processGoawayFrame(_ frame: HTTP2Frame) {
        // Connection will be closed
        // Could extract last stream ID and error code if needed
    }

    private func getOrCreateStream(_ streamId: UInt32) -> HTTP2Stream {
        if let stream = streams[streamId] {
            return stream
        }
        let stream = HTTP2Stream(streamId: streamId)
        streams[streamId] = stream
        return stream
    }

    /// Get all streams
    func getStreams() -> [HTTP2Stream] {
        return Array(streams.values)
    }

    /// Get stream by ID
    func getStream(_ streamId: UInt32) -> HTTP2Stream? {
        return streams[streamId]
    }

    /// Reset parser state
    func reset() {
        buffer.removeAll()
        streams.removeAll()
    }
}

/// HTTP/2 Frame Builder
class HTTP2FrameBuilder {

    /// Build a frame
    static func buildFrame(
        type: HTTP2FrameType,
        flags: HTTP2FrameFlags = [],
        streamId: UInt32,
        payload: Data
    ) -> Data {
        var frame = Data()

        // Length (24 bits)
        let length = UInt32(payload.count)
        frame.append(UInt8((length >> 16) & 0xFF))
        frame.append(UInt8((length >> 8) & 0xFF))
        frame.append(UInt8(length & 0xFF))

        // Type
        frame.append(type.rawValue)

        // Flags
        frame.append(flags.rawValue)

        // Stream ID (with reserved bit = 0)
        frame.append(UInt8((streamId >> 24) & 0x7F))
        frame.append(UInt8((streamId >> 16) & 0xFF))
        frame.append(UInt8((streamId >> 8) & 0xFF))
        frame.append(UInt8(streamId & 0xFF))

        // Payload
        frame.append(payload)

        return frame
    }

    /// Build SETTINGS frame
    static func buildSettingsFrame(settings: HTTP2Settings, ack: Bool = false) -> Data {
        if ack {
            return buildFrame(
                type: .settings,
                flags: HTTP2FrameFlags(rawValue: 0x1),
                streamId: 0,
                payload: Data()
            )
        }

        var payload = Data()

        // Header Table Size
        payload.append(contentsOf: [0x00, 0x01])
        payload.append(contentsOf: withUnsafeBytes(of: settings.headerTableSize.bigEndian) { Array($0) })

        // Enable Push
        payload.append(contentsOf: [0x00, 0x02])
        payload.append(contentsOf: withUnsafeBytes(of: (settings.enablePush ? UInt32(1) : UInt32(0)).bigEndian) { Array($0) })

        // Max Concurrent Streams
        payload.append(contentsOf: [0x00, 0x03])
        payload.append(contentsOf: withUnsafeBytes(of: settings.maxConcurrentStreams.bigEndian) { Array($0) })

        // Initial Window Size
        payload.append(contentsOf: [0x00, 0x04])
        payload.append(contentsOf: withUnsafeBytes(of: settings.initialWindowSize.bigEndian) { Array($0) })

        // Max Frame Size
        payload.append(contentsOf: [0x00, 0x05])
        payload.append(contentsOf: withUnsafeBytes(of: settings.maxFrameSize.bigEndian) { Array($0) })

        return buildFrame(type: .settings, streamId: 0, payload: payload)
    }

    /// Build HEADERS frame
    static func buildHeadersFrame(
        streamId: UInt32,
        headers: [(String, String)],
        encoder: HPACKEncoder,
        endStream: Bool = false,
        endHeaders: Bool = true
    ) -> Data {
        let headerBlock = encoder.encode(headers)

        var flags = HTTP2FrameFlags()
        if endStream { flags.insert(.endStream) }
        if endHeaders { flags.insert(.endHeaders) }

        return buildFrame(
            type: .headers,
            flags: flags,
            streamId: streamId,
            payload: headerBlock
        )
    }

    /// Build DATA frame
    static func buildDataFrame(
        streamId: UInt32,
        data: Data,
        endStream: Bool = false
    ) -> Data {
        var flags = HTTP2FrameFlags()
        if endStream { flags.insert(.endStream) }

        return buildFrame(
            type: .data,
            flags: flags,
            streamId: streamId,
            payload: data
        )
    }

    /// Build WINDOW_UPDATE frame
    static func buildWindowUpdateFrame(streamId: UInt32, increment: UInt32) -> Data {
        var payload = Data()
        payload.append(UInt8((increment >> 24) & 0x7F))
        payload.append(UInt8((increment >> 16) & 0xFF))
        payload.append(UInt8((increment >> 8) & 0xFF))
        payload.append(UInt8(increment & 0xFF))

        return buildFrame(type: .windowUpdate, streamId: streamId, payload: payload)
    }

    /// Build GOAWAY frame
    static func buildGoawayFrame(lastStreamId: UInt32, errorCode: UInt32) -> Data {
        var payload = Data()

        // Last Stream ID
        payload.append(UInt8((lastStreamId >> 24) & 0x7F))
        payload.append(UInt8((lastStreamId >> 16) & 0xFF))
        payload.append(UInt8((lastStreamId >> 8) & 0xFF))
        payload.append(UInt8(lastStreamId & 0xFF))

        // Error Code
        payload.append(contentsOf: withUnsafeBytes(of: errorCode.bigEndian) { Array($0) })

        return buildFrame(type: .goaway, streamId: 0, payload: payload)
    }

    /// Build RST_STREAM frame
    static func buildRstStreamFrame(streamId: UInt32, errorCode: UInt32) -> Data {
        var payload = Data()
        payload.append(contentsOf: withUnsafeBytes(of: errorCode.bigEndian) { Array($0) })

        return buildFrame(type: .rstStream, streamId: streamId, payload: payload)
    }

    /// Build PING frame
    static func buildPingFrame(data: Data = Data(count: 8), ack: Bool = false) -> Data {
        var flags = HTTP2FrameFlags()
        if ack { flags = HTTP2FrameFlags(rawValue: 0x1) }

        var payload = data
        if payload.count < 8 {
            payload.append(Data(count: 8 - payload.count))
        } else if payload.count > 8 {
            payload = Data(payload[0..<8])
        }

        return buildFrame(type: .ping, flags: flags, streamId: 0, payload: payload)
    }
}
