import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../app/theme/app_theme.dart';
import '../../services/certificate_service.dart';
import '../home/home_controller.dart';

/// Settings screen with proxy configuration, certificates, and app settings
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _portController = TextEditingController(text: '8888');
  bool _sslInterception = true;
  String? _certPath;
  bool _certExists = false;
  bool _certTrusted = false;
  Map<String, String>? _certInfo;
  final _certService = CertificateService.instance;

  @override
  void initState() {
    super.initState();
    _checkCertificate();
  }

  Future<void> _checkCertificate() async {
    final exists = await _certService.syrahCertificateExists();
    final trusted = await _certService.isCertificateTrusted();
    final info = await _certService.getCertificateInfo();
    final path = _certService.certificatePath;

    setState(() {
      _certPath = path;
      _certExists = exists;
      _certTrusted = trusted;
      _certInfo = info;
    });
  }

  @override
  void dispose() {
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Check if we're in bottom navigation context (no navigator history)
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        automaticallyImplyLeading: canPop, // Only show back button if pushed from elsewhere
        leading: canPop
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Proxy Settings
          _buildSectionHeader('Proxy Settings'),
          _buildCard([
            _buildPortSetting(),
            const Divider(height: 1),
            _buildSslToggle(),
          ]),
          const SizedBox(height: 24),

          // Certificate Settings
          _buildSectionHeader('SSL Certificate'),
          _buildCard([
            _buildCertificateInfo(),
            const Divider(height: 1),
            _buildCertificateActions(),
          ]),
          const SizedBox(height: 24),

          // App Settings
          _buildSectionHeader('Appearance'),
          _buildCard([
            _buildThemeSetting(),
          ]),
          const SizedBox(height: 24),

          // Data Management
          _buildSectionHeader('Data'),
          _buildCard([
            _buildClearDataOption(),
            const Divider(height: 1),
            _buildExportOption(),
          ]),
          const SizedBox(height: 24),

          // About
          _buildSectionHeader('About'),
          _buildCard([
            _buildAboutInfo(),
          ]),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildPortSetting() {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.router, color: AppColors.primary, size: 20),
      ),
      title: const Text('Proxy Port'),
      subtitle: const Text('Port for the HTTP/HTTPS proxy server'),
      trailing: SizedBox(
        width: 80,
        child: TextField(
          controller: _portController,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: 'monospace'),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSslToggle() {
    return SwitchListTile(
      secondary: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.success.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.lock, color: AppColors.success, size: 20),
      ),
      title: const Text('SSL Interception'),
      subtitle: const Text('Decrypt HTTPS traffic (requires CA certificate)'),
      value: _sslInterception,
      onChanged: (value) => setState(() => _sslInterception = value),
    );
  }

  Widget _buildCertificateInfo() {
    final statusColor = _certExists
        ? (_certTrusted ? AppColors.success : AppColors.warning)
        : AppColors.error;
    final statusIcon = _certExists
        ? (_certTrusted ? Icons.verified : Icons.warning_amber)
        : Icons.cancel;
    final statusText = _certExists
        ? (_certTrusted ? 'Trusted' : 'Not Trusted')
        : 'Not Generated';

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: statusColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(statusIcon, color: statusColor, size: 20),
      ),
      title: const Text('SyrahProxy CA Certificate'),
      subtitle: Text(
        _certExists
            ? (_certInfo?['subject'] ?? 'Certificate at ~/.syrah/')
            : 'Click "Trust Certificate" in toolbar to generate',
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: statusColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          statusText,
          style: TextStyle(color: statusColor, fontSize: 12),
        ),
      ),
      onTap: () => CertificateService.showInstallDialog(context),
    );
  }

  Widget _buildCertificateActions() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _certExists ? _copyCertPath : null,
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('Copy Path'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _certExists ? _openCertFolder : null,
              icon: const Icon(Icons.folder_open, size: 18),
              label: const Text('Open Folder'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              onPressed: () => CertificateService.showInstallDialog(context).then((_) => _checkCertificate()),
              icon: Icon(_certExists ? Icons.refresh : Icons.add, size: 18),
              label: Text(_certExists ? 'Manage' : 'Generate'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeSetting() {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.accent.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.palette, color: AppColors.accent, size: 20),
      ),
      title: const Text('Theme'),
      subtitle: const Text('App appearance'),
      trailing: SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'light', icon: Icon(Icons.light_mode, size: 18)),
          ButtonSegment(value: 'system', icon: Icon(Icons.settings_suggest, size: 18)),
          ButtonSegment(value: 'dark', icon: Icon(Icons.dark_mode, size: 18)),
        ],
        selected: const {'light'},
        onSelectionChanged: (value) {
          // TODO: Implement theme switching
        },
      ),
    );
  }

  Widget _buildClearDataOption() {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
      ),
      title: const Text('Clear All Data'),
      subtitle: const Text('Remove all captured requests and settings'),
      trailing: const Icon(Icons.chevron_right),
      onTap: _showClearDataDialog,
    );
  }

  Widget _buildExportOption() {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.info.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.file_download, color: AppColors.info, size: 20),
      ),
      title: const Text('Export as HAR'),
      subtitle: const Text('Export captured requests in HAR format'),
      trailing: const Icon(Icons.chevron_right),
      onTap: _exportAsHar,
    );
  }

  Widget _buildAboutInfo() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // App icon - Wine glass logo
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.asset(
              'assets/icons/syrah_logo.png',
              width: 64,
              height: 64,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFF722F37),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.wine_bar, color: Colors.white, size: 32),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'SyrahProxy',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Open Source Network Debugging Proxy',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Version 1.0.0',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondaryLight,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'proxy.syrah.dev',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.primary,
                ),
          ),
          const SizedBox(height: 16),
          Text(
            'Powered by mitmproxy',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondaryLight,
                ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () async {
                  await Process.run('open', ['https://github.com/benyaminsalimi/syrah-proxy']);
                },
                child: const Text('GitHub'),
              ),
              const Text('•'),
              TextButton(
                onPressed: () async {
                  await Process.run('open', ['https://proxy.syrah.dev']);
                },
                child: const Text('Website'),
              ),
              const Text('•'),
              TextButton(
                onPressed: () {
                  showLicensePage(
                    context: context,
                    applicationName: 'SyrahProxy',
                    applicationVersion: '1.0.0',
                    applicationLegalese: '© 2026 Syrah Project\nhttps://proxy.syrah.dev',
                  );
                },
                child: const Text('License'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _copyCertPath() {
    if (_certPath != null) {
      Clipboard.setData(ClipboardData(text: _certPath!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Certificate path copied to clipboard'),
          behavior: SnackBarBehavior.floating,
          width: 300,
        ),
      );
    }
  }

  void _openCertFolder() async {
    await _certService.openCertificateFolder();
  }

  void _exportCertificate() async {
    if (_certPath == null) return;

    try {
      final downloads = await getDownloadsDirectory();
      if (downloads != null) {
        final destPath = '${downloads.path}/mitmproxy-ca-cert.pem';
        await File(_certPath!).copy(destPath);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Certificate exported to $destPath'),
              behavior: SnackBarBehavior.floating,
              action: SnackBarAction(
                label: 'Open',
                onPressed: () async {
                  if (Platform.isMacOS) {
                    await Process.run('open', [downloads.path]);
                  }
                },
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export certificate: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showClearDataDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data?'),
        content: const Text(
          'This will remove all captured requests. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(homeControllerProvider.notifier).clearFlows();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('All data cleared'),
                  behavior: SnackBarBehavior.floating,
                  width: 300,
                ),
              );
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _exportAsHar() {
    // TODO: Implement HAR export
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('HAR export coming soon'),
        behavior: SnackBarBehavior.floating,
        width: 300,
      ),
    );
  }
}
