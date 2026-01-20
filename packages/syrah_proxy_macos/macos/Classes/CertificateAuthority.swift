import Foundation
import Security
import CommonCrypto

/// Certificate export formats
enum CertificateExportFormat {
    case der
    case pem
    case pkcs12
}

/// Errors that can occur during certificate operations
enum CertificateError: Error, LocalizedError {
    case keyGenerationFailed
    case certificateGenerationFailed
    case keychainError(OSStatus)
    case exportFailed
    case invalidFormat
    case notFound
    case signingFailed

    var errorDescription: String? {
        switch self {
        case .keyGenerationFailed:
            return "Failed to generate key pair"
        case .certificateGenerationFailed:
            return "Failed to generate certificate"
        case .keychainError(let status):
            return "Keychain error: \(status)"
        case .exportFailed:
            return "Failed to export certificate"
        case .invalidFormat:
            return "Invalid certificate format"
        case .notFound:
            return "Certificate not found"
        case .signingFailed:
            return "Failed to sign certificate"
        }
    }
}

/// Certificate Authority for MITM proxy
class CertificateAuthority {
    private static let caKeyTag = "dev.syrah.proxy.ca.key"
    private static let caCertLabel = "Syrah Proxy CA"

    private var caPrivateKey: SecKey?
    private var caCertificate: SecCertificate?

    // Certificate cache
    private var certificateCache: [String: (SecIdentity, Date)] = [:]
    private let cacheMaxSize = 1000
    private let cacheTTL: TimeInterval = 3600 * 24 // 24 hours

    // Certificate metadata
    var rootCertificateSubject: String = ""
    var rootCertificateIssuer: String = ""
    var rootCertificateSerialNumber: String = ""
    var rootCertificateNotBefore: Date = Date()
    var rootCertificateNotAfter: Date = Date()
    var rootCertificateFingerprint: String = ""

    /// Initialize the Certificate Authority
    init() throws {
        // Try to load existing CA from Keychain
        if loadCAFromKeychain() {
            extractMetadata()
            return
        }

        // Generate new root CA
        try generateRootCA()
        extractMetadata()
    }

    /// Load CA from Keychain - disabled since we run in sandbox without keychain access
    private func loadCAFromKeychain() -> Bool {
        // Keychain access not available in sandbox mode
        // Always generate new CA on startup
        return false
    }

    /// Generate new Root CA
    private func generateRootCA() throws {
        // Generate 2048-bit RSA key pair (ephemeral - no keychain storage needed)
        let keyParams: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeySizeInBits as String: 2048,
            kSecAttrIsPermanent as String: false  // Don't store in keychain
        ]

        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(keyParams as CFDictionary, &error) else {
            print("[CertificateAuthority] Key generation failed: \(error?.takeRetainedValue().localizedDescription ?? "unknown")")
            throw CertificateError.keyGenerationFailed
        }

        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            throw CertificateError.keyGenerationFailed
        }

        // Create self-signed certificate
        let subject = "CN=Syrah Proxy CA,O=Syrah,C=US"
        let validityDays = 3650 // 10 years

        guard let certificate = try createSelfSignedCertificate(
            subject: subject,
            publicKey: publicKey,
            signingKey: privateKey,
            validityDays: validityDays,
            isCA: true
        ) else {
            throw CertificateError.certificateGenerationFailed
        }

        // Skip keychain storage (we don't have keychain access in sandbox)
        // The certificate is kept in memory only
        self.caPrivateKey = privateKey
        self.caCertificate = certificate
        print("[CertificateAuthority] Root CA generated successfully (in-memory only)")
    }

    /// Create a self-signed certificate
    private func createSelfSignedCertificate(
        subject: String,
        publicKey: SecKey,
        signingKey: SecKey,
        validityDays: Int,
        isCA: Bool,
        sans: [String]? = nil
    ) throws -> SecCertificate? {
        // Build X.509 certificate using ASN.1 encoding
        var tbsCert = Data()

        // Version (v3 = 2)
        tbsCert.append(contentsOf: asn1Context(tag: 0, contents: asn1Integer(2)))

        // Serial Number
        let serial = UInt64.random(in: 1...UInt64.max)
        tbsCert.append(contentsOf: asn1Integer(Int64(bitPattern: serial)))

        // Signature Algorithm (SHA-256 with RSA)
        tbsCert.append(contentsOf: asn1Sequence([
            asn1ObjectIdentifier([1, 2, 840, 113549, 1, 1, 11]), // sha256WithRSAEncryption
            asn1Null()
        ]))

        // Issuer (same as subject for self-signed)
        tbsCert.append(contentsOf: parseDN(subject))

        // Validity
        let now = Date()
        let notAfter = Calendar.current.date(byAdding: .day, value: validityDays, to: now)!
        rootCertificateNotBefore = now
        rootCertificateNotAfter = notAfter
        tbsCert.append(contentsOf: asn1Sequence([
            asn1UTCTime(now),
            asn1UTCTime(notAfter)
        ]))

        // Subject
        tbsCert.append(contentsOf: parseDN(subject))

        // Subject Public Key Info
        guard let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, nil) as Data? else {
            throw CertificateError.certificateGenerationFailed
        }
        tbsCert.append(contentsOf: asn1Sequence([
            asn1Sequence([
                asn1ObjectIdentifier([1, 2, 840, 113549, 1, 1, 1]), // rsaEncryption
                asn1Null()
            ]),
            asn1BitString(publicKeyData)
        ]))

        // Extensions (v3)
        var extensions: [Data] = []

        if isCA {
            // Basic Constraints (CA:TRUE)
            extensions.append(asn1Sequence([
                asn1ObjectIdentifier([2, 5, 29, 19]), // basicConstraints
                asn1Boolean(true), // critical
                asn1OctetString(asn1Sequence([asn1Boolean(true)])) // CA:TRUE
            ]))

            // Key Usage (keyCertSign, cRLSign)
            extensions.append(asn1Sequence([
                asn1ObjectIdentifier([2, 5, 29, 15]), // keyUsage
                asn1Boolean(true), // critical
                asn1OctetString(asn1BitString(Data([0x06]))) // keyCertSign | cRLSign
            ]))
        } else {
            // Basic Constraints (CA:FALSE)
            extensions.append(asn1Sequence([
                asn1ObjectIdentifier([2, 5, 29, 19]), // basicConstraints
                asn1OctetString(asn1Sequence([]))
            ]))

            // Key Usage (digitalSignature, keyEncipherment)
            extensions.append(asn1Sequence([
                asn1ObjectIdentifier([2, 5, 29, 15]), // keyUsage
                asn1Boolean(true),
                asn1OctetString(asn1BitString(Data([0x05, 0xa0])))
            ]))

            // Extended Key Usage (serverAuth)
            extensions.append(asn1Sequence([
                asn1ObjectIdentifier([2, 5, 29, 37]), // extKeyUsage
                asn1OctetString(asn1Sequence([
                    asn1ObjectIdentifier([1, 3, 6, 1, 5, 5, 7, 3, 1]) // serverAuth
                ]))
            ]))

            // Subject Alternative Name
            if let sans = sans, !sans.isEmpty {
                var sanData: [Data] = []
                for san in sans {
                    // DNS name (context tag 2)
                    sanData.append(asn1Context(tag: 2, contents: Data(san.utf8), constructed: false))
                }
                if !sanData.isEmpty {
                    extensions.append(asn1Sequence([
                        asn1ObjectIdentifier([2, 5, 29, 17]), // subjectAltName
                        asn1OctetString(asn1Sequence(sanData))
                    ]))
                }
            }
        }

        if !extensions.isEmpty {
            tbsCert.append(contentsOf: asn1Context(tag: 3, contents: asn1Sequence(extensions)))
        }

        let tbsCertSequence = asn1Sequence([tbsCert])

        // Sign TBS Certificate
        guard let signature = try signData(tbsCertSequence, with: signingKey) else {
            throw CertificateError.signingFailed
        }

        // Build complete certificate
        let certData = asn1Sequence([
            tbsCertSequence,
            asn1Sequence([
                asn1ObjectIdentifier([1, 2, 840, 113549, 1, 1, 11]),
                asn1Null()
            ]),
            asn1BitString(signature)
        ])

        return SecCertificateCreateWithData(nil, certData as CFData)
    }

    /// Generate certificate for a domain
    func generateCertificate(for domain: String, sans: [String] = []) throws -> SecIdentity {
        // Check cache
        if let cached = certificateCache[domain], cached.1.timeIntervalSinceNow > -cacheTTL {
            return cached.0
        }

        guard let caKey = caPrivateKey, let _ = caCertificate else {
            throw CertificateError.notFound
        }

        // Generate key pair for this domain
        let keyParams: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeySizeInBits as String: 2048
        ]

        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(keyParams as CFDictionary, &error) else {
            throw CertificateError.keyGenerationFailed
        }

        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            throw CertificateError.keyGenerationFailed
        }

        // Create certificate signed by CA
        let subject = "CN=\(domain),O=Syrah Proxy"
        var allSans = [domain]
        allSans.append(contentsOf: sans)

        guard let certificate = try createSelfSignedCertificate(
            subject: subject,
            publicKey: publicKey,
            signingKey: caKey,
            validityDays: 365,
            isCA: false,
            sans: allSans
        ) else {
            throw CertificateError.certificateGenerationFailed
        }

        // Create identity
        guard let identity = createIdentity(privateKey: privateKey, certificate: certificate) else {
            throw CertificateError.certificateGenerationFailed
        }

        // Cache the identity
        if certificateCache.count >= cacheMaxSize {
            let sorted = certificateCache.sorted { $0.value.1 < $1.value.1 }
            for (key, _) in sorted.prefix(cacheMaxSize / 4) {
                certificateCache.removeValue(forKey: key)
            }
        }
        certificateCache[domain] = (identity, Date())

        return identity
    }

    // Track keychain tags for cleanup
    private var keychainTags: [String] = []

    /// Create SecIdentity from key and certificate
    private func createIdentity(privateKey: SecKey, certificate: SecCertificate) -> SecIdentity? {
        let tempTag = "dev.syrah.proxy.temp.\(UUID().uuidString)"
        keychainTags.append(tempTag)

        // Store private key in keychain
        let keyQuery: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecValueRef as String: privateKey,
            kSecAttrApplicationTag as String: tempTag,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        let keyStatus = SecItemAdd(keyQuery as CFDictionary, nil)
        if keyStatus != errSecSuccess && keyStatus != errSecDuplicateItem {
            print("[CertificateAuthority] Failed to add key to keychain: \(keyStatus)")
            return nil
        }

        // Store certificate in keychain
        let certQuery: [String: Any] = [
            kSecClass as String: kSecClassCertificate,
            kSecValueRef as String: certificate,
            kSecAttrLabel as String: tempTag,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        let certStatus = SecItemAdd(certQuery as CFDictionary, nil)
        if certStatus != errSecSuccess && certStatus != errSecDuplicateItem {
            print("[CertificateAuthority] Failed to add certificate to keychain: \(certStatus)")
            // Clean up key
            SecItemDelete(keyQuery as CFDictionary)
            return nil
        }

        // Get identity by matching certificate
        let identityQuery: [String: Any] = [
            kSecClass as String: kSecClassIdentity,
            kSecAttrLabel as String: tempTag,
            kSecReturnRef as String: true
        ]

        var identityRef: CFTypeRef?
        let status = SecItemCopyMatching(identityQuery as CFDictionary, &identityRef)

        if status == errSecSuccess, let identity = identityRef {
            print("[CertificateAuthority] Created identity successfully for tag: \(tempTag)")
            return (identity as! SecIdentity)
        } else {
            print("[CertificateAuthority] Failed to get identity from keychain: \(status)")
            // Clean up
            SecItemDelete(keyQuery as CFDictionary)
            SecItemDelete(certQuery as CFDictionary)
            return nil
        }
    }

    /// Clean up keychain items created by this CA
    func cleanup() {
        for tag in keychainTags {
            let keyQuery: [String: Any] = [
                kSecClass as String: kSecClassKey,
                kSecAttrApplicationTag as String: tag
            ]
            SecItemDelete(keyQuery as CFDictionary)

            let certQuery: [String: Any] = [
                kSecClass as String: kSecClassCertificate,
                kSecAttrLabel as String: tag
            ]
            SecItemDelete(certQuery as CFDictionary)
        }
        keychainTags.removeAll()
    }

    /// Sign data with private key
    private func signData(_ data: Data, with key: SecKey) throws -> Data? {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }

        var error: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(
            key,
            .rsaSignatureDigestPKCS1v15SHA256,
            Data(hash) as CFData,
            &error
        ) as Data? else {
            throw CertificateError.signingFailed
        }

        return signature
    }

    /// Export root CA certificate
    func exportRootCertificate(format: CertificateExportFormat) throws -> Data {
        guard let cert = caCertificate else {
            throw CertificateError.notFound
        }

        switch format {
        case .der:
            return SecCertificateCopyData(cert) as Data

        case .pem:
            let derData = SecCertificateCopyData(cert) as Data
            let base64 = derData.base64EncodedString(options: [.lineLength64Characters, .endLineWithLineFeed])
            let pem = "-----BEGIN CERTIFICATE-----\n\(base64)\n-----END CERTIFICATE-----\n"
            return pem.data(using: .utf8)!

        case .pkcs12:
            throw CertificateError.exportFailed
        }
    }

    /// Install root certificate to user trust store
    func installRootCertificate() throws {
        guard let certificate = caCertificate else {
            throw CertificateError.notFound
        }

        // Add certificate to user keychain
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassCertificate,
            kSecValueRef as String: certificate,
            kSecAttrLabel as String: Self.caCertLabel
        ]

        var status = SecItemAdd(addQuery as CFDictionary, nil)
        if status == errSecDuplicateItem {
            status = errSecSuccess
        }

        if status != errSecSuccess {
            throw CertificateError.keychainError(status)
        }

        // Set trust settings (trust as root)
        let trustSettings: CFArray = [
            [kSecTrustSettingsResult as String: SecTrustSettingsResult.trustRoot.rawValue]
        ] as CFArray

        status = SecTrustSettingsSetTrustSettings(certificate, .user, trustSettings)
        if status != errSecSuccess {
            throw CertificateError.keychainError(status)
        }
    }

    /// Check if root certificate is trusted
    func isRootCertificateTrusted() -> Bool {
        guard let certificate = caCertificate else {
            return false
        }

        var trustSettings: CFArray?
        let status = SecTrustSettingsCopyTrustSettings(certificate, .user, &trustSettings)

        return status == errSecSuccess && trustSettings != nil
    }

    /// Get CA common name
    func getCACommonName() -> String? {
        guard let cert = caCertificate else { return nil }
        return SecCertificateCopySubjectSummary(cert) as String?
    }

    // MARK: - Metadata

    private func extractMetadata() {
        guard let certificate = caCertificate else { return }

        if let summary = SecCertificateCopySubjectSummary(certificate) as String? {
            rootCertificateSubject = summary
            rootCertificateIssuer = summary
        }

        if let serialData = SecCertificateCopySerialNumberData(certificate, nil) as Data? {
            rootCertificateSerialNumber = serialData.map { String(format: "%02X", $0) }.joined(separator: ":")
        }

        // Calculate SHA-256 fingerprint
        let certData = SecCertificateCopyData(certificate) as Data
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        certData.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(certData.count), &hash)
        }
        rootCertificateFingerprint = hash.map { String(format: "%02X", $0) }.joined(separator: ":")
    }

    // MARK: - ASN.1 Encoding Helpers

    private func asn1Length(_ length: Int) -> Data {
        if length < 128 {
            return Data([UInt8(length)])
        } else if length < 256 {
            return Data([0x81, UInt8(length)])
        } else if length < 65536 {
            return Data([0x82, UInt8(length >> 8), UInt8(length & 0xFF)])
        } else {
            return Data([0x83, UInt8(length >> 16), UInt8((length >> 8) & 0xFF), UInt8(length & 0xFF)])
        }
    }

    private func asn1Sequence(_ contents: [Data]) -> Data {
        var data = Data()
        for content in contents {
            data.append(content)
        }
        return Data([0x30]) + asn1Length(data.count) + data
    }

    private func asn1Sequence(_ contents: Data) -> Data {
        return Data([0x30]) + asn1Length(contents.count) + contents
    }

    private func asn1Set(_ contents: [Data]) -> Data {
        var data = Data()
        for content in contents {
            data.append(content)
        }
        return Data([0x31]) + asn1Length(data.count) + data
    }

    private func asn1Integer(_ value: Int64) -> Data {
        var bytes: [UInt8] = []
        var v = value

        if v == 0 {
            bytes = [0]
        } else if v > 0 {
            while v > 0 {
                bytes.insert(UInt8(v & 0xFF), at: 0)
                v >>= 8
            }
            if bytes[0] & 0x80 != 0 {
                bytes.insert(0, at: 0)
            }
        } else {
            while v < -1 {
                bytes.insert(UInt8(v & 0xFF), at: 0)
                v >>= 8
            }
            bytes.insert(UInt8(v & 0xFF), at: 0)
        }

        return Data([0x02]) + asn1Length(bytes.count) + Data(bytes)
    }

    private func asn1Integer(_ value: Int) -> Data {
        return asn1Integer(Int64(value))
    }

    private func asn1ObjectIdentifier(_ oid: [Int]) -> Data {
        guard oid.count >= 2 else { return Data() }

        var bytes: [UInt8] = [UInt8(oid[0] * 40 + oid[1])]

        for i in 2..<oid.count {
            var value = oid[i]
            var encoded: [UInt8] = []

            encoded.insert(UInt8(value & 0x7F), at: 0)
            value >>= 7

            while value > 0 {
                encoded.insert(UInt8((value & 0x7F) | 0x80), at: 0)
                value >>= 7
            }

            bytes.append(contentsOf: encoded)
        }

        return Data([0x06]) + asn1Length(bytes.count) + Data(bytes)
    }

    private func asn1Null() -> Data {
        return Data([0x05, 0x00])
    }

    private func asn1Boolean(_ value: Bool) -> Data {
        return Data([0x01, 0x01, value ? 0xFF : 0x00])
    }

    private func asn1BitString(_ data: Data) -> Data {
        var result = Data([0x03])
        result.append(contentsOf: asn1Length(data.count + 1))
        result.append(0x00) // Unused bits
        result.append(data)
        return result
    }

    private func asn1OctetString(_ data: Data) -> Data {
        return Data([0x04]) + asn1Length(data.count) + data
    }

    private func asn1UTF8String(_ string: String) -> Data {
        let data = Data(string.utf8)
        return Data([0x0C]) + asn1Length(data.count) + data
    }

    private func asn1PrintableString(_ string: String) -> Data {
        let data = Data(string.utf8)
        return Data([0x13]) + asn1Length(data.count) + data
    }

    private func asn1UTCTime(_ date: Date) -> Data {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyMMddHHmmss'Z'"
        formatter.timeZone = TimeZone(identifier: "UTC")
        let string = formatter.string(from: date)
        let data = Data(string.utf8)
        return Data([0x17]) + asn1Length(data.count) + data
    }

    private func asn1Context(tag: Int, contents: Data, constructed: Bool = true) -> Data {
        if constructed {
            return Data([UInt8(0xA0 | tag)]) + asn1Length(contents.count) + contents
        } else {
            return Data([UInt8(0x80 | tag)]) + asn1Length(contents.count) + contents
        }
    }

    private func parseDN(_ dn: String) -> Data {
        var rdns: [Data] = []

        let parts = dn.split(separator: ",")
        for part in parts {
            let kv = part.split(separator: "=", maxSplits: 1)
            guard kv.count == 2 else { continue }

            let key = kv[0].trimmingCharacters(in: .whitespaces)
            let value = kv[1].trimmingCharacters(in: .whitespaces)

            let oid: [Int]
            switch key.uppercased() {
            case "CN": oid = [2, 5, 4, 3]
            case "O": oid = [2, 5, 4, 10]
            case "OU": oid = [2, 5, 4, 11]
            case "C": oid = [2, 5, 4, 6]
            case "ST": oid = [2, 5, 4, 8]
            case "L": oid = [2, 5, 4, 7]
            default: continue
            }

            let atv = asn1Sequence([
                asn1ObjectIdentifier(oid),
                key.uppercased() == "C" ? asn1PrintableString(value) : asn1UTF8String(value)
            ])

            rdns.append(asn1Set([atv]))
        }

        return asn1Sequence(rdns)
    }
}
