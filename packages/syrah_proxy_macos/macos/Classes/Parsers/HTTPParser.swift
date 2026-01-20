import Foundation
import Compression

/// HTTP request parsing result
struct ParsedHTTPRequest {
    let method: String
    let path: String
    let version: String
    let headers: [String: String]
    let body: Data?
    let host: String?
    let isComplete: Bool
    let rawSize: Int
}

/// HTTP response parsing result
struct ParsedHTTPResponse {
    let version: String
    let statusCode: Int
    let statusMessage: String
    let headers: [String: String]
    let body: Data?
    let isComplete: Bool
    let rawSize: Int
}

/// HTTP/1.1 Parser
class HTTPParser {

    enum ParserState {
        case readingRequestLine
        case readingStatusLine
        case readingHeaders
        case readingBody
        case complete
        case error(String)
    }

    private var state: ParserState = .readingRequestLine
    private var buffer = Data()
    private var headers: [String: String] = [:]
    private var bodyData = Data()

    // Request fields
    private var method: String?
    private var path: String?
    private var httpVersion: String?

    // Response fields
    private var statusCode: Int?
    private var statusMessage: String?

    // Body handling
    private var contentLength: Int?
    private var isChunked = false
    private var currentChunkSize: Int?

    private let isRequest: Bool

    init(isRequest: Bool) {
        self.isRequest = isRequest
        self.state = isRequest ? .readingRequestLine : .readingStatusLine
    }

    /// Feed data to the parser
    func feed(_ data: Data) {
        buffer.append(data)
        parse()
    }

    /// Check if parsing is complete
    var isComplete: Bool {
        if case .complete = state {
            return true
        }
        return false
    }

    /// Check if there was an error
    var hasError: Bool {
        if case .error = state {
            return true
        }
        return false
    }

    /// Get parsed request (only valid for request parser)
    func getRequest() -> ParsedHTTPRequest? {
        guard isRequest else { return nil }

        return ParsedHTTPRequest(
            method: method ?? "GET",
            path: path ?? "/",
            version: httpVersion ?? "HTTP/1.1",
            headers: headers,
            body: bodyData.isEmpty ? nil : bodyData,
            host: headers["Host"] ?? headers["host"],
            isComplete: isComplete,
            rawSize: buffer.count
        )
    }

    /// Get parsed response (only valid for response parser)
    func getResponse() -> ParsedHTTPResponse? {
        guard !isRequest else { return nil }

        return ParsedHTTPResponse(
            version: httpVersion ?? "HTTP/1.1",
            statusCode: statusCode ?? 0,
            statusMessage: statusMessage ?? "",
            headers: headers,
            body: bodyData.isEmpty ? nil : bodyData,
            isComplete: isComplete,
            rawSize: buffer.count
        )
    }

    // MARK: - Private Parsing Methods

    private func parse() {
        while true {
            switch state {
            case .readingRequestLine:
                guard parseRequestLine() else { return }
            case .readingStatusLine:
                guard parseStatusLine() else { return }
            case .readingHeaders:
                guard parseHeaders() else { return }
            case .readingBody:
                guard parseBody() else { return }
            case .complete, .error:
                return
            }
        }
    }

    private func parseRequestLine() -> Bool {
        guard let lineEnd = findLineEnd() else { return false }

        let line = String(data: buffer[..<lineEnd], encoding: .utf8) ?? ""
        buffer.removeFirst(lineEnd + 2) // Remove line + CRLF

        let parts = line.split(separator: " ", maxSplits: 2)
        guard parts.count >= 2 else {
            state = .error("Invalid request line")
            return false
        }

        method = String(parts[0])
        path = String(parts[1])
        httpVersion = parts.count > 2 ? String(parts[2]) : "HTTP/1.1"

        state = .readingHeaders
        return true
    }

    private func parseStatusLine() -> Bool {
        guard let lineEnd = findLineEnd() else { return false }

        let line = String(data: buffer[..<lineEnd], encoding: .utf8) ?? ""
        buffer.removeFirst(lineEnd + 2)

        let parts = line.split(separator: " ", maxSplits: 2)
        guard parts.count >= 2 else {
            state = .error("Invalid status line")
            return false
        }

        httpVersion = String(parts[0])
        statusCode = Int(parts[1])
        statusMessage = parts.count > 2 ? String(parts[2]) : ""

        state = .readingHeaders
        return true
    }

    private func parseHeaders() -> Bool {
        while let lineEnd = findLineEnd() {
            let line = String(data: buffer[..<lineEnd], encoding: .utf8) ?? ""
            buffer.removeFirst(lineEnd + 2)

            // Empty line marks end of headers
            if line.isEmpty {
                processHeaders()
                state = contentLength == 0 && !isChunked ? .complete : .readingBody
                return true
            }

            // Parse header
            if let colonIndex = line.firstIndex(of: ":") {
                let name = String(line[..<colonIndex]).trimmingCharacters(in: .whitespaces)
                let value = String(line[line.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                headers[name] = value
            }
        }
        return false
    }

    private func processHeaders() {
        // Check for Content-Length
        if let lengthStr = headers["Content-Length"] ?? headers["content-length"],
           let length = Int(lengthStr) {
            contentLength = length
        }

        // Check for Transfer-Encoding: chunked
        let transferEncoding = headers["Transfer-Encoding"] ?? headers["transfer-encoding"] ?? ""
        isChunked = transferEncoding.lowercased().contains("chunked")

        // No body for certain responses
        if !isRequest {
            if let code = statusCode, (code < 200 || code == 204 || code == 304) {
                contentLength = 0
            }
        }

        // No body for certain requests
        if isRequest {
            if method == "GET" || method == "HEAD" || method == "DELETE" || method == "OPTIONS" {
                if contentLength == nil {
                    contentLength = 0
                }
            }
        }
    }

    private func parseBody() -> Bool {
        if isChunked {
            return parseChunkedBody()
        } else if let length = contentLength {
            return parseFixedLengthBody(length: length)
        } else {
            // Read until connection close (not ideal, but handles edge cases)
            bodyData.append(buffer)
            buffer.removeAll()
            return false
        }
    }

    private func parseFixedLengthBody(length: Int) -> Bool {
        let remaining = length - bodyData.count
        let available = min(remaining, buffer.count)

        bodyData.append(buffer[..<available])
        buffer.removeFirst(available)

        if bodyData.count >= length {
            state = .complete
            return true
        }
        return false
    }

    private func parseChunkedBody() -> Bool {
        while true {
            if let chunkSize = currentChunkSize {
                // Read chunk data
                if chunkSize == 0 {
                    // Final chunk - look for trailing CRLF
                    if buffer.count >= 2 {
                        buffer.removeFirst(2)
                        state = .complete
                        return true
                    }
                    return false
                }

                let needed = chunkSize + 2 // chunk + CRLF
                if buffer.count >= needed {
                    bodyData.append(buffer[..<chunkSize])
                    buffer.removeFirst(needed)
                    currentChunkSize = nil
                } else {
                    return false
                }
            } else {
                // Read chunk size line
                guard let lineEnd = findLineEnd() else { return false }

                let line = String(data: buffer[..<lineEnd], encoding: .utf8) ?? ""
                buffer.removeFirst(lineEnd + 2)

                // Parse hex chunk size (ignore extensions after semicolon)
                let sizeStr = line.split(separator: ";").first ?? ""
                guard let size = Int(sizeStr, radix: 16) else {
                    state = .error("Invalid chunk size")
                    return false
                }

                currentChunkSize = size
            }
        }
    }

    private func findLineEnd() -> Int? {
        // Find CRLF
        for i in 0..<buffer.count - 1 {
            if buffer[i] == 0x0D && buffer[i + 1] == 0x0A { // \r\n
                return i
            }
        }
        return nil
    }

    /// Reset parser for reuse
    func reset() {
        state = isRequest ? .readingRequestLine : .readingStatusLine
        buffer.removeAll()
        headers.removeAll()
        bodyData.removeAll()
        method = nil
        path = nil
        httpVersion = nil
        statusCode = nil
        statusMessage = nil
        contentLength = nil
        isChunked = false
        currentChunkSize = nil
    }
}

// MARK: - HTTP Message Builder

class HTTPMessageBuilder {

    /// Build HTTP request data from components
    static func buildRequest(
        method: String,
        path: String,
        headers: [String: String],
        body: Data? = nil,
        version: String = "HTTP/1.1"
    ) -> Data {
        var message = "\(method) \(path) \(version)\r\n"

        var finalHeaders = headers
        if let body = body, finalHeaders["Content-Length"] == nil {
            finalHeaders["Content-Length"] = String(body.count)
        }

        for (name, value) in finalHeaders {
            message += "\(name): \(value)\r\n"
        }
        message += "\r\n"

        var data = message.data(using: .utf8) ?? Data()
        if let body = body {
            data.append(body)
        }

        return data
    }

    /// Build HTTP response data from components
    static func buildResponse(
        statusCode: Int,
        statusMessage: String,
        headers: [String: String],
        body: Data? = nil,
        version: String = "HTTP/1.1"
    ) -> Data {
        var message = "\(version) \(statusCode) \(statusMessage)\r\n"

        var finalHeaders = headers
        if let body = body, finalHeaders["Content-Length"] == nil {
            finalHeaders["Content-Length"] = String(body.count)
        }

        for (name, value) in finalHeaders {
            message += "\(name): \(value)\r\n"
        }
        message += "\r\n"

        var data = message.data(using: .utf8) ?? Data()
        if let body = body {
            data.append(body)
        }

        return data
    }
}

// MARK: - Content Encoding

class ContentEncoder {

    /// Decompress data based on Content-Encoding header
    static func decompress(_ data: Data, encoding: String?) -> Data {
        guard let encoding = encoding?.lowercased() else { return data }

        switch encoding {
        case "gzip":
            return gunzip(data) ?? data
        case "deflate":
            return inflate(data) ?? data
        case "br":
            // Brotli not natively supported, return as-is
            return data
        default:
            return data
        }
    }

    /// Compress data with gzip
    static func gzip(_ data: Data) -> Data? {
        // Use Compression framework
        guard !data.isEmpty else { return data }

        var compressed = Data()

        // Simple gzip header
        compressed.append(contentsOf: [0x1f, 0x8b, 0x08, 0x00]) // Magic + method
        compressed.append(contentsOf: [0x00, 0x00, 0x00, 0x00]) // Timestamp
        compressed.append(contentsOf: [0x00, 0x03]) // Extra flags + OS

        // Compress with zlib
        if let deflated = deflate(data) {
            compressed.append(deflated)
        }

        // CRC32 and original size
        let crc = crc32(data)
        compressed.append(contentsOf: withUnsafeBytes(of: crc.littleEndian) { Array($0) })
        let size = UInt32(data.count)
        compressed.append(contentsOf: withUnsafeBytes(of: size.littleEndian) { Array($0) })

        return compressed
    }

    /// Decompress gzip data
    static func gunzip(_ data: Data) -> Data? {
        guard data.count > 18 else { return nil }

        // Check gzip magic number
        guard data[0] == 0x1f && data[1] == 0x8b else { return nil }

        // Skip header (simplified - doesn't handle all flags)
        var offset = 10

        let flags = data[3]
        if flags & 0x04 != 0 { // FEXTRA
            let xlen = Int(data[offset]) | (Int(data[offset + 1]) << 8)
            offset += 2 + xlen
        }
        if flags & 0x08 != 0 { // FNAME
            while offset < data.count && data[offset] != 0 { offset += 1 }
            offset += 1
        }
        if flags & 0x10 != 0 { // FCOMMENT
            while offset < data.count && data[offset] != 0 { offset += 1 }
            offset += 1
        }
        if flags & 0x02 != 0 { // FHCRC
            offset += 2
        }

        let compressedData = data[offset..<(data.count - 8)]
        return inflate(Data(compressedData))
    }

    /// Deflate compression
    static func deflate(_ data: Data) -> Data? {
        let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: data.count + 1024)
        defer { destinationBuffer.deallocate() }

        let result = data.withUnsafeBytes { sourcePtr -> Int in
            guard let baseAddress = sourcePtr.baseAddress else { return 0 }
            return compression_encode_buffer(
                destinationBuffer,
                data.count + 1024,
                baseAddress.assumingMemoryBound(to: UInt8.self),
                data.count,
                nil,
                COMPRESSION_ZLIB
            )
        }

        guard result > 0 else { return nil }
        return Data(bytes: destinationBuffer, count: result)
    }

    /// Inflate decompression
    static func inflate(_ data: Data) -> Data? {
        // Estimate decompressed size (4x compressed typically)
        var destinationSize = data.count * 4
        var destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: destinationSize)

        var result = data.withUnsafeBytes { sourcePtr -> Int in
            guard let baseAddress = sourcePtr.baseAddress else { return 0 }
            return compression_decode_buffer(
                destinationBuffer,
                destinationSize,
                baseAddress.assumingMemoryBound(to: UInt8.self),
                data.count,
                nil,
                COMPRESSION_ZLIB
            )
        }

        // If buffer too small, try larger
        if result == 0 || result == destinationSize {
            destinationBuffer.deallocate()
            destinationSize = data.count * 16
            destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: destinationSize)

            result = data.withUnsafeBytes { sourcePtr -> Int in
                guard let baseAddress = sourcePtr.baseAddress else { return 0 }
                return compression_decode_buffer(
                    destinationBuffer,
                    destinationSize,
                    baseAddress.assumingMemoryBound(to: UInt8.self),
                    data.count,
                    nil,
                    COMPRESSION_ZLIB
                )
            }
        }

        defer { destinationBuffer.deallocate() }

        guard result > 0 else { return nil }
        return Data(bytes: destinationBuffer, count: result)
    }

    /// Calculate CRC32
    static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF

        let table: [UInt32] = (0..<256).map { i -> UInt32 in
            var c = UInt32(i)
            for _ in 0..<8 {
                c = (c & 1) != 0 ? (0xEDB88320 ^ (c >> 1)) : (c >> 1)
            }
            return c
        }

        for byte in data {
            crc = table[Int((crc ^ UInt32(byte)) & 0xFF)] ^ (crc >> 8)
        }

        return crc ^ 0xFFFFFFFF
    }
}
