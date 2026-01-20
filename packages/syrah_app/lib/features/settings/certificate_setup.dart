import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_theme.dart';

/// Screen for managing CA certificate setup
class CertificateSetupScreen extends ConsumerStatefulWidget {
  const CertificateSetupScreen({super.key});

  @override
  ConsumerState<CertificateSetupScreen> createState() =>
      _CertificateSetupScreenState();
}

class _CertificateSetupScreenState
    extends ConsumerState<CertificateSetupScreen> {
  bool _isGenerating = false;
  bool _hasExistingCert = true; // Would check from native side

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Certificate Authority'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status card
            _buildStatusCard(context),
            const SizedBox(height: 24),

            // Installation guide
            _buildInstallationGuide(context),
            const SizedBox(height: 24),

            // Actions
            _buildActions(context),
            const SizedBox(height: 24),

            // Advanced options
            _buildAdvancedOptions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _hasExistingCert
                        ? AppColors.success.withOpacity(0.1)
                        : AppColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _hasExistingCert ? Icons.verified : Icons.warning_amber,
                    color: _hasExistingCert
                        ? AppColors.success
                        : AppColors.warning,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _hasExistingCert
                            ? 'Certificate Ready'
                            : 'Certificate Required',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _hasExistingCert
                            ? 'CA certificate is generated and ready for installation'
                            : 'Generate a CA certificate to enable HTTPS interception',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_hasExistingCert) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              _buildCertInfo('Common Name', 'SyrahProxy CA'),
              _buildCertInfo('Organization', 'SyrahProxy'),
              _buildCertInfo('Valid From', '2024-01-01'),
              _buildCertInfo('Valid To', '2034-01-01'),
              _buildCertInfo('Fingerprint (SHA-256)',
                  'AB:CD:EF:12:34:56:78:90...'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCertInfo(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.code.copyWith(fontSize: 12),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 16),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Copied to clipboard')),
              );
            },
            visualDensity: VisualDensity.compact,
            tooltip: 'Copy',
          ),
        ],
      ),
    );
  }

  Widget _buildInstallationGuide(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Installation Guide',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        if (Platform.isMacOS) _buildMacOSGuide(context),
        if (Platform.isAndroid) _buildAndroidGuide(context),
        _buildOtherPlatformsGuide(context),
      ],
    );
  }

  Widget _buildMacOSGuide(BuildContext context) {
    return _InstallationCard(
      icon: Icons.laptop_mac,
      platform: 'macOS',
      steps: const [
        'Click "Export Certificate" below',
        'Open the downloaded .pem file',
        'Keychain Access will open automatically',
        'Double-click the certificate and select "Always Trust"',
        'Enter your password when prompted',
      ],
      action: FilledButton.icon(
        onPressed: _exportCertificate,
        icon: const Icon(Icons.download),
        label: const Text('Export Certificate'),
      ),
    );
  }

  Widget _buildAndroidGuide(BuildContext context) {
    return _InstallationCard(
      icon: Icons.android,
      platform: 'Android',
      steps: const [
        'Click "Export Certificate" below',
        'Open Settings → Security → Encryption & credentials',
        'Tap "Install a certificate" → "CA certificate"',
        'Select the downloaded .pem file',
        'The certificate will be installed for this user',
      ],
      action: FilledButton.icon(
        onPressed: _exportCertificate,
        icon: const Icon(Icons.download),
        label: const Text('Export Certificate'),
      ),
      note: 'Note: Android 7+ requires app-specific configuration for '
          'user-installed CA certificates. See documentation for details.',
    );
  }

  Widget _buildOtherPlatformsGuide(BuildContext context) {
    return ExpansionTile(
      title: const Text('Other Platforms'),
      children: [
        _PlatformGuide(
          platform: 'iOS / iPadOS',
          steps: const [
            'Share the certificate to your iOS device',
            'Open Settings → Profile Downloaded',
            'Install the profile',
            'Go to Settings → General → About → Certificate Trust Settings',
            'Enable full trust for the SyrahProxy CA',
          ],
        ),
        _PlatformGuide(
          platform: 'Windows',
          steps: const [
            'Export the certificate as .cer format',
            'Double-click the certificate file',
            'Click "Install Certificate"',
            'Select "Local Machine" and "Trusted Root Certification Authorities"',
          ],
        ),
        _PlatformGuide(
          platform: 'Linux',
          steps: const [
            'Copy the .pem file to /usr/local/share/ca-certificates/',
            'Run: sudo update-ca-certificates',
            'For Firefox: Import manually in Preferences → Certificates',
          ],
        ),
      ],
    );
  }

  Widget _buildActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Actions',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _hasExistingCert ? _exportCertificate : null,
              icon: const Icon(Icons.download),
              label: const Text('Export (.pem)'),
            ),
            OutlinedButton.icon(
              onPressed: _hasExistingCert ? _exportDerCertificate : null,
              icon: const Icon(Icons.download),
              label: const Text('Export (.der)'),
            ),
            OutlinedButton.icon(
              onPressed: _hasExistingCert ? _shareCertificate : null,
              icon: const Icon(Icons.share),
              label: const Text('Share'),
            ),
            OutlinedButton.icon(
              onPressed: _hasExistingCert ? _copyFingerprint : null,
              icon: const Icon(Icons.fingerprint),
              label: const Text('Copy Fingerprint'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAdvancedOptions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Advanced',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.refresh),
                title: const Text('Regenerate Certificate'),
                subtitle: const Text('Create a new CA certificate'),
                trailing: _isGenerating
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.chevron_right),
                onTap: _isGenerating ? null : _regenerateCertificate,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.upload_file),
                title: const Text('Import Custom CA'),
                subtitle: const Text('Use your own certificate'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _importCustomCA,
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.delete_outline, color: AppColors.error),
                title: Text(
                  'Delete Certificate',
                  style: TextStyle(color: AppColors.error),
                ),
                subtitle: const Text('Remove the current CA certificate'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _deleteCertificate,
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _exportCertificate() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Certificate exported as .pem')),
    );
  }

  void _exportDerCertificate() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Certificate exported as .der')),
    );
  }

  void _shareCertificate() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Share sheet would open here')),
    );
  }

  void _copyFingerprint() {
    Clipboard.setData(
      const ClipboardData(text: 'AB:CD:EF:12:34:56:78:90...'),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Fingerprint copied to clipboard')),
    );
  }

  void _regenerateCertificate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Regenerate Certificate?'),
        content: const Text(
          'This will create a new CA certificate. You will need to '
          'reinstall the certificate on all your devices.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Regenerate'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isGenerating = true);
      await Future.delayed(const Duration(seconds: 2));
      setState(() => _isGenerating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Certificate regenerated')),
        );
      }
    }
  }

  void _importCustomCA() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('File picker would open here')),
    );
  }

  void _deleteCertificate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Certificate?'),
        content: const Text(
          'This will remove the CA certificate. HTTPS interception will '
          'stop working until a new certificate is generated.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _hasExistingCert = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Certificate deleted')),
        );
      }
    }
  }
}

/// Installation card for a platform
class _InstallationCard extends StatelessWidget {
  final IconData icon;
  final String platform;
  final List<String> steps;
  final Widget action;
  final String? note;

  const _InstallationCard({
    required this.icon,
    required this.platform,
    required this.steps,
    required this.action,
    this.note,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 24),
                const SizedBox(width: 8),
                Text(
                  platform,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...List.generate(steps.length, (index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        steps[index],
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              );
            }),
            if (note != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 16,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        note!,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            action,
          ],
        ),
      ),
    );
  }
}

/// Platform-specific guide item
class _PlatformGuide extends StatelessWidget {
  final String platform;
  final List<String> steps;

  const _PlatformGuide({
    required this.platform,
    required this.steps,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            platform,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ...steps.map((step) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• '),
                    Expanded(child: Text(step)),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
