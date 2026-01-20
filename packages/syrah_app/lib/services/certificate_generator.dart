import 'dart:io';

/// Service to generate custom CA certificates for SyrahProxy
class CertificateGenerator {
  static CertificateGenerator? _instance;
  static CertificateGenerator get instance => _instance ??= CertificateGenerator._();

  CertificateGenerator._();

  /// Get the Syrah certificate directory
  String get certDirectory {
    final home = Platform.environment['HOME'];
    return '$home/.syrah';
  }

  /// Get paths to certificate files
  String get caKeyPath => '$certDirectory/syrah-ca.key';
  String get caCertPath => '$certDirectory/syrah-ca-cert.pem';
  String get caCertDerPath => '$certDirectory/syrah-ca-cert.cer';
  String get caP12Path => '$certDirectory/syrah-ca-cert.p12';
  String get configPath => '$certDirectory/config.yaml';

  /// Check if Syrah certificates already exist
  Future<bool> certificatesExist() async {
    return await File(caCertPath).exists() && await File(caKeyPath).exists();
  }

  /// Get certificate info if it exists
  Future<Map<String, String>?> getCertificateInfo() async {
    if (!await certificatesExist()) return null;

    try {
      final result = await Process.run('openssl', [
        'x509',
        '-in', caCertPath,
        '-noout',
        '-subject',
        '-dates',
        '-fingerprint',
        '-sha256',
      ]);

      if (result.exitCode != 0) return null;

      final output = result.stdout as String;
      final info = <String, String>{};

      // Parse output
      for (final line in output.split('\n')) {
        if (line.startsWith('subject=')) {
          info['subject'] = line.substring(8).trim();
        } else if (line.startsWith('notBefore=')) {
          info['notBefore'] = line.substring(10).trim();
        } else if (line.startsWith('notAfter=')) {
          info['notAfter'] = line.substring(9).trim();
        } else if (line.contains('Fingerprint=')) {
          info['fingerprint'] = line.split('=').last.trim();
        }
      }

      return info;
    } catch (e) {
      print('[CertificateGenerator] Error getting cert info: $e');
      return null;
    }
  }

  /// Generate new CA certificate for SyrahProxy
  Future<bool> generateCertificate({
    String organizationName = 'SyrahProxy',
    String commonName = 'SyrahProxy CA',
    int validityDays = 3650, // 10 years
  }) async {
    try {
      // Create directory if it doesn't exist
      final dir = Directory(certDirectory);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      print('[CertificateGenerator] Generating new CA certificate...');
      print('[CertificateGenerator] Organization: $organizationName');
      print('[CertificateGenerator] Common Name: $commonName');
      print('[CertificateGenerator] Validity: $validityDays days');

      // Generate private key (RSA 2048)
      var result = await Process.run('openssl', [
        'genrsa',
        '-out', caKeyPath,
        '2048',
      ]);

      if (result.exitCode != 0) {
        print('[CertificateGenerator] Failed to generate private key: ${result.stderr}');
        return false;
      }

      // Set restrictive permissions on private key
      await Process.run('chmod', ['600', caKeyPath]);

      // Generate self-signed CA certificate
      result = await Process.run('openssl', [
        'req',
        '-new',
        '-x509',
        '-key', caKeyPath,
        '-out', caCertPath,
        '-days', validityDays.toString(),
        '-subj', '/CN=$commonName/O=$organizationName',
        '-addext', 'basicConstraints=critical,CA:TRUE',
        '-addext', 'keyUsage=critical,keyCertSign,cRLSign',
        '-addext', 'subjectKeyIdentifier=hash',
      ]);

      if (result.exitCode != 0) {
        print('[CertificateGenerator] Failed to generate certificate: ${result.stderr}');
        return false;
      }

      // Convert to DER format for some systems
      result = await Process.run('openssl', [
        'x509',
        '-in', caCertPath,
        '-outform', 'DER',
        '-out', caCertDerPath,
      ]);

      if (result.exitCode != 0) {
        print('[CertificateGenerator] Warning: Failed to create DER format: ${result.stderr}');
      }

      // Create PKCS12 format (for iOS/macOS Keychain)
      result = await Process.run('openssl', [
        'pkcs12',
        '-export',
        '-out', caP12Path,
        '-inkey', caKeyPath,
        '-in', caCertPath,
        '-passout', 'pass:',
        '-name', commonName,
      ]);

      if (result.exitCode != 0) {
        print('[CertificateGenerator] Warning: Failed to create P12 format: ${result.stderr}');
      }

      // Create mitmproxy config to use our CA
      await _createMitmproxyConfig();

      print('[CertificateGenerator] Certificate generated successfully!');
      print('[CertificateGenerator] Location: $certDirectory');

      return true;
    } catch (e) {
      print('[CertificateGenerator] Error generating certificate: $e');
      return false;
    }
  }

  /// Create mitmproxy configuration to use Syrah CA
  Future<void> _createMitmproxyConfig() async {
    // mitmproxy can use a custom CA by placing it in its confdir
    // We'll create a combined PEM file (key + cert) that mitmproxy expects

    final combinedPath = '$certDirectory/mitmproxy-ca.pem';

    try {
      final keyContent = await File(caKeyPath).readAsString();
      final certContent = await File(caCertPath).readAsString();

      // mitmproxy expects key first, then cert
      await File(combinedPath).writeAsString('$keyContent$certContent');

      // Also copy cert as mitmproxy-ca-cert.pem
      await File(caCertPath).copy('$certDirectory/mitmproxy-ca-cert.pem');

      print('[CertificateGenerator] Created mitmproxy-compatible CA files');
    } catch (e) {
      print('[CertificateGenerator] Error creating mitmproxy config: $e');
    }
  }

  /// Delete existing certificates
  Future<bool> deleteCertificates() async {
    try {
      // Try to remove from Keychain (requires user permission)
      // This removes the trusted certificate so regeneration works properly
      if (Platform.isMacOS) {
        final home = Platform.environment['HOME'];
        print('[CertificateGenerator] Attempting to remove old certificate from Keychain...');

        // Try to delete from login keychain (most common location)
        var result = await Process.run('security', [
          'delete-certificate',
          '-c', 'SyrahProxy CA',
          '-t',  // Also delete trust settings
          '$home/Library/Keychains/login.keychain-db',
        ]);
        print('[CertificateGenerator] Login keychain delete result: ${result.exitCode}');

        // Also try without -db suffix (older macOS)
        result = await Process.run('security', [
          'delete-certificate',
          '-c', 'SyrahProxy CA',
          '-t',
          '$home/Library/Keychains/login.keychain',
        ]);

        // Try default keychain search
        result = await Process.run('security', [
          'delete-certificate',
          '-c', 'SyrahProxy CA',
          '-t',
        ]);
        print('[CertificateGenerator] Default keychain delete result: ${result.exitCode}');

        // System keychain needs sudo, will likely fail but try anyway
        await Process.run('security', [
          'delete-certificate',
          '-c', 'SyrahProxy CA',
          '-t',
          '/Library/Keychains/System.keychain',
        ]);

        print('[CertificateGenerator] Keychain cleanup attempted');
      }

      // Delete certificate files
      final dir = Directory(certDirectory);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
      print('[CertificateGenerator] Certificates deleted');
      return true;
    } catch (e) {
      print('[CertificateGenerator] Error deleting certificates: $e');
      return false;
    }
  }

  /// Open certificate for installation
  Future<bool> openCertificateForInstall() async {
    if (!await certificatesExist()) return false;

    try {
      final result = await Process.run('open', [caCertPath]);
      return result.exitCode == 0;
    } catch (e) {
      print('[CertificateGenerator] Error opening certificate: $e');
      return false;
    }
  }

  /// Open certificate folder in Finder
  Future<bool> openCertificateFolder() async {
    try {
      final result = await Process.run('open', [certDirectory]);
      return result.exitCode == 0;
    } catch (e) {
      print('[CertificateGenerator] Error opening folder: $e');
      return false;
    }
  }

  /// Get the confdir argument for mitmproxy to use Syrah certificates
  String get mitmproxyConfDir => certDirectory;
}
