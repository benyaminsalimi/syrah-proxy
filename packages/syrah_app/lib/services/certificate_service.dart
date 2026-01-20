import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'certificate_generator.dart';

/// Service to manage SyrahProxy CA certificate installation
class CertificateService {
  static CertificateService? _instance;
  static CertificateService get instance => _instance ??= CertificateService._();

  CertificateService._();

  final _generator = CertificateGenerator.instance;

  /// Get the path to the Syrah CA certificate (preferred) or mitmproxy fallback
  String? get certificatePath {
    final home = Platform.environment['HOME'];
    if (home == null) return null;

    // Prefer Syrah certificate
    final syrahCert = '$home/.syrah/syrah-ca-cert.pem';
    if (File(syrahCert).existsSync()) {
      return syrahCert;
    }

    // Fallback to mitmproxy default
    return '$home/.mitmproxy/mitmproxy-ca-cert.pem';
  }

  /// Check if Syrah certificate exists
  Future<bool> syrahCertificateExists() async {
    return _generator.certificatesExist();
  }

  /// Generate new Syrah certificate
  Future<bool> generateCertificate() async {
    return _generator.generateCertificate();
  }

  /// Get certificate info
  Future<Map<String, String>?> getCertificateInfo() async {
    return _generator.getCertificateInfo();
  }

  /// Delete certificates
  Future<bool> deleteCertificates() async {
    return _generator.deleteCertificates();
  }

  /// Check if the certificate file exists
  Future<bool> certificateExists() async {
    final path = certificatePath;
    if (path == null) return false;
    return File(path).exists();
  }

  /// Check if the Syrah certificate is trusted in macOS Keychain
  Future<bool> isCertificateTrusted() async {
    if (!Platform.isMacOS) return false;

    try {
      // Check for SyrahProxy CA first
      var result = await Process.run('security', [
        'find-certificate',
        '-c',
        'SyrahProxy CA',
        '/Library/Keychains/System.keychain'
      ]);

      if (result.exitCode == 0) {
        // Check if it's trusted
        final verifyResult = await Process.run('security', [
          'verify-cert',
          '-c', _generator.caCertPath,
        ]);
        return verifyResult.exitCode == 0;
      }

      // Fallback: check for mitmproxy cert
      result = await Process.run('security', [
        'find-certificate',
        '-c',
        'mitmproxy',
        '/Library/Keychains/System.keychain'
      ]);

      return result.exitCode == 0;
    } catch (e) {
      print('[CertificateService] Error checking trust status: $e');
      return false;
    }
  }

  /// Open the certificate file for installation (will prompt Keychain)
  Future<bool> openCertificateForInstall() async {
    final path = certificatePath;
    if (path == null || !await certificateExists()) {
      return false;
    }

    try {
      final result = await Process.run('open', [path]);
      return result.exitCode == 0;
    } catch (e) {
      print('[CertificateService] Error opening certificate: $e');
      return false;
    }
  }

  /// Open Keychain Access app
  Future<bool> openKeychainAccess() async {
    if (!Platform.isMacOS) return false;

    try {
      final result = await Process.run('open', [
        '-a',
        'Keychain Access'
      ]);
      return result.exitCode == 0;
    } catch (e) {
      print('[CertificateService] Error opening Keychain Access: $e');
      return false;
    }
  }

  /// Copy certificate path to clipboard
  Future<void> copyCertificatePath() async {
    final path = certificatePath;
    if (path != null) {
      await Clipboard.setData(ClipboardData(text: path));
    }
  }

  /// Open the folder containing the certificate
  Future<bool> openCertificateFolder() async {
    final path = certificatePath;
    if (path == null) return false;

    try {
      final folder = File(path).parent.path;
      final result = await Process.run('open', [folder]);
      return result.exitCode == 0;
    } catch (e) {
      print('[CertificateService] Error opening folder: $e');
      return false;
    }
  }

  /// Install certificate using security command (requires user interaction for sudo)
  /// Returns the command string for the user to run manually
  String getTrustCommand() {
    final path = certificatePath;
    return 'sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain $path';
  }

  /// Show certificate installation dialog
  static Future<void> showInstallDialog(BuildContext context) async {
    final service = CertificateService.instance;
    final syrahExists = await service.syrahCertificateExists();
    final certInfo = await service.getCertificateInfo();

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => _CertificateDialog(
        syrahExists: syrahExists,
        certInfo: certInfo,
        service: service,
      ),
    );
  }

  static Widget _buildStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue.shade700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

/// Certificate management dialog
class _CertificateDialog extends StatefulWidget {
  final bool syrahExists;
  final Map<String, String>? certInfo;
  final CertificateService service;

  const _CertificateDialog({
    required this.syrahExists,
    required this.certInfo,
    required this.service,
  });

  @override
  State<_CertificateDialog> createState() => _CertificateDialogState();
}

class _CertificateDialogState extends State<_CertificateDialog> {
  bool _isGenerating = false;
  bool _isCheckingTrust = false;
  bool _certExists = false;
  bool _isTrusted = false;
  Map<String, String>? _certInfo;

  @override
  void initState() {
    super.initState();
    _certExists = widget.syrahExists;
    _certInfo = widget.certInfo;
    _checkTrustStatus();
  }

  Future<void> _checkTrustStatus() async {
    if (!_certExists) return;

    setState(() => _isCheckingTrust = true);
    final trusted = await widget.service.isCertificateTrusted();
    if (mounted) {
      setState(() {
        _isTrusted = trusted;
        _isCheckingTrust = false;
      });
    }
  }

  String _formatValidity(String? notAfter) {
    if (notAfter == null) return 'Unknown';
    try {
      // Parse date like "Jan 18 01:37:08 2036 GMT"
      final parts = notAfter.split(' ');
      if (parts.length >= 4) {
        final year = parts[3];
        final month = parts[0];
        final day = parts[1];
        return '$month $day, $year';
      }
      return notAfter;
    } catch (e) {
      return notAfter;
    }
  }

  int? _getValidityYears(String? notAfter) {
    if (notAfter == null) return null;
    try {
      final parts = notAfter.split(' ');
      if (parts.length >= 4) {
        final year = int.tryParse(parts[3]);
        if (year != null) {
          return year - DateTime.now().year;
        }
      }
    } catch (e) {
      // ignore
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.security, color: Colors.blue),
          SizedBox(width: 12),
          Text('SyrahProxy Certificate'),
        ],
      ),
      content: SizedBox(
        width: 550,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Certificate status
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _certExists
                    ? (_isTrusted ? Colors.green.shade50 : Colors.orange.shade50)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _certExists
                      ? (_isTrusted ? Colors.green.shade200 : Colors.orange.shade200)
                      : Colors.grey.shade300,
                ),
              ),
              child: Row(
                children: [
                  if (_isCheckingTrust)
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Icon(
                      _certExists
                          ? (_isTrusted ? Icons.verified : Icons.warning_amber_rounded)
                          : Icons.cancel,
                      color: _certExists
                          ? (_isTrusted ? Colors.green : Colors.orange)
                          : Colors.grey,
                      size: 24,
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _certExists
                              ? (_isTrusted ? 'Certificate Trusted' : 'Certificate Not Trusted')
                              : 'No Certificate',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: _certExists
                                ? (_isTrusted ? Colors.green.shade800 : Colors.orange.shade800)
                                : Colors.grey.shade700,
                          ),
                        ),
                        if (_certInfo != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Subject: ${_certInfo!['subject'] ?? 'Unknown'}',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                          ),
                          Row(
                            children: [
                              Text(
                                'Valid until: ${_formatValidity(_certInfo!['notAfter'])}',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                              ),
                              if (_getValidityYears(_certInfo!['notAfter']) != null) ...[
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${_getValidityYears(_certInfo!['notAfter'])} years',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (_certExists && !_isCheckingTrust) ...[
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 20),
                      onPressed: _checkTrustStatus,
                      tooltip: 'Recheck trust status',
                      color: Colors.grey.shade600,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (!_certExists) ...[
              // Generate certificate section
              const Text(
                'Generate a new SyrahProxy CA certificate:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              const Text(
                'This will create a unique certificate for your installation. '
                'The certificate will be named "SyrahProxy CA" and stored locally.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isGenerating ? null : _generateCertificate,
                  icon: _isGenerating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.add_circle_outline),
                  label: Text(_isGenerating ? 'Generating...' : 'Generate Certificate'),
                ),
              ),
            ] else if (_isTrusted) ...[
              // Certificate is trusted - show success
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green.shade700, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Your certificate is trusted and ready to use!',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Colors.green.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'HTTPS traffic will now be decrypted. Restart your browser if you haven\'t already.',
                      style: TextStyle(fontSize: 12, color: Colors.green.shade700),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Fingerprint
              if (_certInfo?['fingerprint'] != null) ...[
                Text(
                  'Fingerprint (SHA-256):',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  _certInfo!['fingerprint']!,
                  style: const TextStyle(
                    fontSize: 10,
                    fontFamily: 'monospace',
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ] else ...[
              // Install certificate section
              const Text(
                'To capture HTTPS traffic, trust this certificate:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 12),
              _buildStep('1', 'Click "Install Certificate" below'),
              _buildStep('2', 'Click "Add" in the system dialog'),
              _buildStep('3', 'Open Keychain Access'),
              _buildStep('4', 'Find "SyrahProxy CA" certificate'),
              _buildStep('5', 'Double-click → Trust → "Always Trust"'),
              _buildStep('6', 'Enter your password'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.amber.shade700, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Restart your browser after trusting the certificate.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Fingerprint
              if (_certInfo?['fingerprint'] != null) ...[
                Text(
                  'Fingerprint (SHA-256):',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  _certInfo!['fingerprint']!,
                  style: const TextStyle(
                    fontSize: 10,
                    fontFamily: 'monospace',
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
      actions: [
        if (_certExists) ...[
          TextButton.icon(
            onPressed: _regenerateCertificate,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Regenerate'),
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
          ),
        ],
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(_isTrusted ? 'Done' : 'Close'),
        ),
        if (_certExists && !_isTrusted) ...[
          OutlinedButton.icon(
            onPressed: () async {
              await widget.service.openKeychainAccess();
            },
            icon: const Icon(Icons.key, size: 18),
            label: const Text('Open Keychain'),
          ),
          FilledButton.icon(
            onPressed: () async {
              await widget.service.openCertificateForInstall();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Certificate opened. Follow the steps to trust "SyrahProxy CA".'),
                    behavior: SnackBarBehavior.floating,
                    width: 450,
                  ),
                );
                // Recheck trust status after a delay
                Future.delayed(const Duration(seconds: 3), () {
                  if (mounted) _checkTrustStatus();
                });
              }
            },
            icon: const Icon(Icons.download, size: 18),
            label: const Text('Install Certificate'),
          ),
        ],
        if (_certExists && _isTrusted) ...[
          FilledButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.check, size: 18),
            label: const Text('All Set!'),
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
          ),
        ],
      ],
    );
  }

  Widget _buildStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue.shade700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Future<void> _generateCertificate() async {
    setState(() => _isGenerating = true);

    final success = await widget.service.generateCertificate();

    if (success) {
      final info = await widget.service.getCertificateInfo();
      setState(() {
        _certExists = true;
        _certInfo = info;
        _isGenerating = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('SyrahProxy CA certificate generated successfully!'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      setState(() => _isGenerating = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to generate certificate. Check console for details.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _regenerateCertificate() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Regenerate Certificate?'),
        content: const Text(
          'This will delete the existing certificate and generate a new one.\n\n'
          'You will need to trust the new certificate in Keychain again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Regenerate'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await widget.service.deleteCertificates();
      setState(() {
        _certExists = false;
        _certInfo = null;
      });
      await _generateCertificate();
    }
  }
}
