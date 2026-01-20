package dev.syrah.syrah_proxy_android

import android.content.Context
import android.util.Base64
import org.bouncycastle.asn1.x500.X500Name
import org.bouncycastle.asn1.x509.BasicConstraints
import org.bouncycastle.asn1.x509.ExtendedKeyUsage
import org.bouncycastle.asn1.x509.Extension
import org.bouncycastle.asn1.x509.GeneralName
import org.bouncycastle.asn1.x509.GeneralNames
import org.bouncycastle.asn1.x509.KeyPurposeId
import org.bouncycastle.asn1.x509.KeyUsage
import org.bouncycastle.cert.X509CertificateHolder
import org.bouncycastle.cert.X509v3CertificateBuilder
import org.bouncycastle.cert.jcajce.JcaX509CertificateConverter
import org.bouncycastle.cert.jcajce.JcaX509v3CertificateBuilder
import org.bouncycastle.jce.provider.BouncyCastleProvider
import org.bouncycastle.operator.jcajce.JcaContentSignerBuilder
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.math.BigInteger
import java.security.KeyPair
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.MessageDigest
import java.security.Security
import java.security.cert.Certificate
import java.security.cert.X509Certificate
import java.util.Calendar
import java.util.concurrent.ConcurrentHashMap

/**
 * Certificate Authority for Android MITM proxy
 */
class CertificateAuthority(private val context: Context) {

    enum class ExportFormat {
        PEM,
        DER
    }

    private var rootKeyPair: KeyPair? = null
    private var rootCertificate: X509Certificate? = null

    private val certificateCache = ConcurrentHashMap<String, Pair<KeyPair, X509Certificate>>()
    private val cacheMaxSize = 500

    var rootCertificateSubject: String = ""
        private set
    var rootCertificateIssuer: String = ""
        private set
    var rootCertificateSerialNumber: String = ""
        private set
    var rootCertificateFingerprint: String = ""
        private set

    init {
        // Register BouncyCastle provider
        if (Security.getProvider(BouncyCastleProvider.PROVIDER_NAME) == null) {
            Security.addProvider(BouncyCastleProvider())
        }

        // Load or generate root CA
        if (!loadFromStorage()) {
            generateRootCA()
            saveToStorage()
        }
        extractMetadata()
    }

    /**
     * Generate a new root CA certificate
     */
    private fun generateRootCA() {
        // Generate 2048-bit RSA key pair
        val keyPairGenerator = KeyPairGenerator.getInstance("RSA")
        keyPairGenerator.initialize(2048)
        rootKeyPair = keyPairGenerator.generateKeyPair()

        // Create self-signed certificate
        val subject = X500Name("CN=Syrah Proxy CA,O=Syrah,C=US")
        val serial = BigInteger.valueOf(System.currentTimeMillis())

        val notBefore = Calendar.getInstance().apply { add(Calendar.DAY_OF_MONTH, -1) }.time
        val notAfter = Calendar.getInstance().apply { add(Calendar.YEAR, 10) }.time

        val certBuilder = JcaX509v3CertificateBuilder(
            subject, // issuer
            serial,
            notBefore,
            notAfter,
            subject, // subject (same as issuer for self-signed)
            rootKeyPair!!.public
        )

        // Add extensions
        certBuilder.addExtension(
            Extension.basicConstraints,
            true,
            BasicConstraints(true) // CA:TRUE
        )

        certBuilder.addExtension(
            Extension.keyUsage,
            true,
            KeyUsage(KeyUsage.keyCertSign or KeyUsage.cRLSign)
        )

        // Sign the certificate
        val signer = JcaContentSignerBuilder("SHA256WithRSAEncryption")
            .setProvider(BouncyCastleProvider.PROVIDER_NAME)
            .build(rootKeyPair!!.private)

        val certHolder = certBuilder.build(signer)
        rootCertificate = JcaX509CertificateConverter()
            .setProvider(BouncyCastleProvider.PROVIDER_NAME)
            .getCertificate(certHolder)
    }

    /**
     * Generate a certificate for a specific domain
     */
    fun generateCertificate(domain: String): Pair<KeyPair, X509Certificate> {
        // Check cache
        certificateCache[domain]?.let { return it }

        // Generate key pair for this domain
        val keyPairGenerator = KeyPairGenerator.getInstance("RSA")
        keyPairGenerator.initialize(2048)
        val keyPair = keyPairGenerator.generateKeyPair()

        // Create certificate
        val subject = X500Name("CN=$domain,O=Syrah Proxy")
        val serial = BigInteger.valueOf(System.currentTimeMillis())

        val notBefore = Calendar.getInstance().apply { add(Calendar.DAY_OF_MONTH, -1) }.time
        val notAfter = Calendar.getInstance().apply { add(Calendar.YEAR, 1) }.time

        val certBuilder = JcaX509v3CertificateBuilder(
            X500Name(rootCertificate!!.subjectX500Principal.name), // issuer
            serial,
            notBefore,
            notAfter,
            subject,
            keyPair.public
        )

        // Add extensions
        certBuilder.addExtension(
            Extension.basicConstraints,
            false,
            BasicConstraints(false) // CA:FALSE
        )

        certBuilder.addExtension(
            Extension.keyUsage,
            true,
            KeyUsage(KeyUsage.digitalSignature or KeyUsage.keyEncipherment)
        )

        certBuilder.addExtension(
            Extension.extendedKeyUsage,
            false,
            ExtendedKeyUsage(KeyPurposeId.id_kp_serverAuth)
        )

        // Subject Alternative Name
        val san = GeneralNames(GeneralName(GeneralName.dNSName, domain))
        certBuilder.addExtension(Extension.subjectAlternativeName, false, san)

        // Sign with root CA
        val signer = JcaContentSignerBuilder("SHA256WithRSAEncryption")
            .setProvider(BouncyCastleProvider.PROVIDER_NAME)
            .build(rootKeyPair!!.private)

        val certHolder = certBuilder.build(signer)
        val certificate = JcaX509CertificateConverter()
            .setProvider(BouncyCastleProvider.PROVIDER_NAME)
            .getCertificate(certHolder)

        // Cache the result
        if (certificateCache.size >= cacheMaxSize) {
            // Remove oldest entries
            val keysToRemove = certificateCache.keys.take(cacheMaxSize / 4)
            keysToRemove.forEach { certificateCache.remove(it) }
        }
        certificateCache[domain] = Pair(keyPair, certificate)

        return Pair(keyPair, certificate)
    }

    /**
     * Get root certificate chain
     */
    fun getRootCertificateChain(): Array<Certificate> {
        return arrayOf(rootCertificate!!)
    }

    /**
     * Export root certificate
     */
    fun exportRootCertificate(format: ExportFormat): ByteArray {
        return when (format) {
            ExportFormat.DER -> rootCertificate!!.encoded
            ExportFormat.PEM -> {
                val base64 = Base64.encodeToString(
                    rootCertificate!!.encoded,
                    Base64.DEFAULT
                )
                "-----BEGIN CERTIFICATE-----\n$base64-----END CERTIFICATE-----\n".toByteArray()
            }
        }
    }

    /**
     * Save CA to storage
     */
    private fun saveToStorage() {
        try {
            val keyStore = KeyStore.getInstance("PKCS12")
            keyStore.load(null, null)

            keyStore.setKeyEntry(
                "ca",
                rootKeyPair!!.private,
                CA_PASSWORD.toCharArray(),
                arrayOf(rootCertificate)
            )

            val file = File(context.filesDir, CA_KEYSTORE_FILE)
            FileOutputStream(file).use { fos ->
                keyStore.store(fos, CA_PASSWORD.toCharArray())
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    /**
     * Load CA from storage
     */
    private fun loadFromStorage(): Boolean {
        try {
            val file = File(context.filesDir, CA_KEYSTORE_FILE)
            if (!file.exists()) return false

            val keyStore = KeyStore.getInstance("PKCS12")
            FileInputStream(file).use { fis ->
                keyStore.load(fis, CA_PASSWORD.toCharArray())
            }

            val key = keyStore.getKey("ca", CA_PASSWORD.toCharArray())
            val cert = keyStore.getCertificate("ca") as? X509Certificate

            if (key != null && cert != null) {
                rootKeyPair = KeyPair(cert.publicKey, key as java.security.PrivateKey)
                rootCertificate = cert
                return true
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return false
    }

    /**
     * Extract certificate metadata
     */
    private fun extractMetadata() {
        rootCertificate?.let { cert ->
            rootCertificateSubject = cert.subjectX500Principal.name
            rootCertificateIssuer = cert.issuerX500Principal.name
            rootCertificateSerialNumber = cert.serialNumber.toString(16)

            // Calculate SHA-256 fingerprint
            val md = MessageDigest.getInstance("SHA-256")
            val digest = md.digest(cert.encoded)
            rootCertificateFingerprint = digest.joinToString(":") { "%02X".format(it) }
        }
    }

    companion object {
        private const val CA_KEYSTORE_FILE = "syrah_ca.p12"
        private const val CA_PASSWORD = "syrah_proxy_ca"
    }
}
