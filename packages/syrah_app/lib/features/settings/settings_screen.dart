import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme/app_theme.dart';
import 'certificate_setup.dart';

/// Main settings screen
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // Proxy Settings
          _SettingsSection(
            title: 'Proxy',
            icon: Icons.router,
            children: [
              _SettingsTile(
                title: 'Port',
                subtitle: '8080',
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showPortEditor(context),
              ),
              _SettingsTile(
                title: 'Listen Address',
                subtitle: '127.0.0.1 (localhost only)',
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showAddressSelector(context),
              ),
              const _ToggleSettingsTile(
                title: 'Auto-start Proxy',
                subtitle: 'Start capturing on app launch',
                settingKey: 'autoStartProxy',
                defaultValue: false,
              ),
            ],
          ),

          // SSL/TLS Settings
          _SettingsSection(
            title: 'SSL/TLS',
            icon: Icons.security,
            children: [
              _SettingsTile(
                title: 'Certificate Authority',
                subtitle: 'Manage root CA certificate',
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CertificateSetupScreen(),
                  ),
                ),
              ),
              const _ToggleSettingsTile(
                title: 'Decrypt HTTPS Traffic',
                subtitle: 'Enable SSL/TLS interception',
                settingKey: 'decryptHttps',
                defaultValue: true,
              ),
              const _ToggleSettingsTile(
                title: 'Ignore Certificate Errors',
                subtitle: 'Skip upstream certificate validation',
                settingKey: 'ignoreCertErrors',
                defaultValue: false,
              ),
            ],
          ),

          // Capture Settings
          _SettingsSection(
            title: 'Capture',
            icon: Icons.filter_alt,
            children: [
              _SettingsTile(
                title: 'Include Filters',
                subtitle: 'Only capture matching traffic',
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showFilterEditor(context, true),
              ),
              _SettingsTile(
                title: 'Exclude Filters',
                subtitle: 'Ignore matching traffic',
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showFilterEditor(context, false),
              ),
              const _ToggleSettingsTile(
                title: 'Capture Binary Bodies',
                subtitle: 'Store image and binary content',
                settingKey: 'captureBinaryBodies',
                defaultValue: false,
              ),
            ],
          ),

          // Display Settings
          _SettingsSection(
            title: 'Display',
            icon: Icons.palette,
            children: [
              _SettingsTile(
                title: 'Theme',
                subtitle: 'System default',
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showThemeSelector(context),
              ),
              const _ToggleSettingsTile(
                title: 'Show Request Preview',
                subtitle: 'Show body preview in list',
                settingKey: 'showPreview',
                defaultValue: true,
              ),
              _SettingsTile(
                title: 'Timestamp Format',
                subtitle: '24-hour',
                trailing: const Icon(Icons.chevron_right),
                onTap: () {},
              ),
            ],
          ),

          // Performance Settings
          _SettingsSection(
            title: 'Performance',
            icon: Icons.speed,
            children: [
              _SettingsTile(
                title: 'Max Stored Requests',
                subtitle: '5000',
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showMaxRequestsEditor(context),
              ),
              _SettingsTile(
                title: 'Max Body Size',
                subtitle: '10 MB',
                trailing: const Icon(Icons.chevron_right),
                onTap: () {},
              ),
              const _ToggleSettingsTile(
                title: 'Auto-clear on Memory Warning',
                subtitle: 'Clear old requests when memory is low',
                settingKey: 'autoClearMemory',
                defaultValue: true,
              ),
            ],
          ),

          // Network Throttling
          _SettingsSection(
            title: 'Network Throttling',
            icon: Icons.network_check,
            children: [
              const _ToggleSettingsTile(
                title: 'Enable Throttling',
                subtitle: 'Simulate slow network conditions',
                settingKey: 'enableThrottling',
                defaultValue: false,
              ),
              _SettingsTile(
                title: 'Profile',
                subtitle: 'Fast 3G',
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showThrottlingProfiles(context),
              ),
            ],
          ),

          // Export/Import
          _SettingsSection(
            title: 'Data',
            icon: Icons.storage,
            children: [
              _SettingsTile(
                title: 'Export All Rules',
                subtitle: 'Save rules as JSON',
                trailing: const Icon(Icons.download),
                onTap: () {},
              ),
              _SettingsTile(
                title: 'Import Rules',
                subtitle: 'Load rules from file',
                trailing: const Icon(Icons.upload),
                onTap: () {},
              ),
              _SettingsTile(
                title: 'Clear All Data',
                subtitle: 'Reset app to default state',
                trailing: const Icon(Icons.delete_forever, color: AppColors.error),
                onTap: () => _showClearDataDialog(context),
              ),
            ],
          ),

          // About
          _SettingsSection(
            title: 'About',
            icon: Icons.info,
            children: [
              // App logo and info
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
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
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.wine_bar,
                              color: Colors.white,
                              size: 40,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'SyrahProxy',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Open Source Network Debugging Proxy',
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'proxy.syrah.dev',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _SettingsTile(
                title: 'Version',
                subtitle: '1.0.0 (Build 1)',
                onTap: () {},
              ),
              _SettingsTile(
                title: 'Open Source Licenses',
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: 'SyrahProxy',
                  applicationVersion: '1.0.0',
                  applicationIcon: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
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
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.wine_bar,
                              color: Colors.white,
                              size: 40,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  applicationLegalese: '© 2026 Syrah Project\nhttps://proxy.syrah.dev',
                ),
              ),
              _SettingsTile(
                title: 'GitHub Repository',
                subtitle: 'github.com/benyaminsalimi/syrah-proxy',
                trailing: const Icon(Icons.open_in_new),
                onTap: () async {
                  if (Platform.isMacOS) {
                    await Process.run('open', ['https://github.com/benyaminsalimi/syrah-proxy']);
                  } else {
                    await launchUrl(
                      Uri.parse('https://github.com/benyaminsalimi/syrah-proxy'),
                      mode: LaunchMode.externalApplication,
                    );
                  }
                },
              ),
              _SettingsTile(
                title: 'Website',
                subtitle: 'proxy.syrah.dev',
                trailing: const Icon(Icons.open_in_new),
                onTap: () async {
                  if (Platform.isMacOS) {
                    await Process.run('open', ['https://proxy.syrah.dev']);
                  } else {
                    await launchUrl(
                      Uri.parse('https://proxy.syrah.dev'),
                      mode: LaunchMode.externalApplication,
                    );
                  }
                },
              ),
            ],
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _showPortEditor(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const _PortEditorDialog(),
    );
  }

  void _showAddressSelector(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Listen Address'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context),
            child: const ListTile(
              title: Text('127.0.0.1'),
              subtitle: Text('Localhost only (most secure)'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context),
            child: const ListTile(
              title: Text('0.0.0.0'),
              subtitle: Text('All interfaces (for remote devices)'),
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterEditor(BuildContext context, bool isInclude) {
    showDialog(
      context: context,
      builder: (context) => _FilterEditorDialog(isInclude: isInclude),
    );
  }

  void _showThemeSelector(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Theme'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context),
            child: const ListTile(
              leading: Icon(Icons.brightness_auto),
              title: Text('System'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context),
            child: const ListTile(
              leading: Icon(Icons.light_mode),
              title: Text('Light'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context),
            child: const ListTile(
              leading: Icon(Icons.dark_mode),
              title: Text('Dark'),
            ),
          ),
        ],
      ),
    );
  }

  void _showMaxRequestsEditor(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const _MaxRequestsDialog(),
    );
  }

  void _showThrottlingProfiles(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Throttling Profile'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context),
            child: const ListTile(
              title: Text('No throttling'),
              subtitle: Text('Full speed'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context),
            child: const ListTile(
              title: Text('Slow 3G'),
              subtitle: Text('400 Kbps, 400ms latency'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context),
            child: const ListTile(
              title: Text('Fast 3G'),
              subtitle: Text('1.5 Mbps, 100ms latency'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context),
            child: const ListTile(
              title: Text('Slow 4G'),
              subtitle: Text('3 Mbps, 50ms latency'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context),
            child: const ListTile(
              title: Text('Fast 4G'),
              subtitle: Text('10 Mbps, 20ms latency'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context),
            child: const ListTile(
              title: Text('Custom...'),
              subtitle: Text('Configure custom profile'),
            ),
          ),
        ],
      ),
    );
  }

  void _showClearDataDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data?'),
        content: const Text(
          'This will delete all captured requests, rules, and settings. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('All data cleared')),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }
}

/// Settings section header
class _SettingsSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SettingsSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
        ...children,
      ],
    );
  }
}

/// Basic settings tile
class _SettingsTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: trailing,
      onTap: onTap,
    );
  }
}

/// Toggle settings tile with switch
class _ToggleSettingsTile extends ConsumerWidget {
  final String title;
  final String subtitle;
  final String settingKey;
  final bool defaultValue;

  const _ToggleSettingsTile({
    required this.title,
    required this.subtitle,
    required this.settingKey,
    required this.defaultValue,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(settingProvider(settingKey)) ?? defaultValue;

    return SwitchListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: (newValue) {
        ref.read(settingsControllerProvider.notifier).setSetting(settingKey, newValue);
      },
    );
  }
}

/// Port editor dialog
class _PortEditorDialog extends StatefulWidget {
  const _PortEditorDialog();

  @override
  State<_PortEditorDialog> createState() => _PortEditorDialogState();
}

class _PortEditorDialogState extends State<_PortEditorDialog> {
  final _controller = TextEditingController(text: '8080');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Proxy Port'),
      content: TextField(
        controller: _controller,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(
          labelText: 'Port number',
          hintText: '8080',
          border: OutlineInputBorder(),
          helperText: 'Valid ports: 1024-65535',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final port = int.tryParse(_controller.text);
            if (port != null && port >= 1024 && port <= 65535) {
              Navigator.pop(context);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Invalid port number'),
                  backgroundColor: AppColors.error,
                ),
              );
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// Filter editor dialog
class _FilterEditorDialog extends StatefulWidget {
  final bool isInclude;

  const _FilterEditorDialog({required this.isInclude});

  @override
  State<_FilterEditorDialog> createState() => _FilterEditorDialogState();
}

class _FilterEditorDialogState extends State<_FilterEditorDialog> {
  final _controller = TextEditingController();
  final _filters = <String>[];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isInclude ? 'Include Filters' : 'Exclude Filters'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: 'URL pattern',
                hintText: '*example.com*',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _addFilter,
                ),
              ),
              onSubmitted: (_) => _addFilter(),
            ),
            const SizedBox(height: 16),
            if (_filters.isEmpty)
              Text(
                'No filters added',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.outline,
                ),
              )
            else
              ...List.generate(_filters.length, (index) {
                return ListTile(
                  dense: true,
                  title: Text(
                    _filters[index],
                    style: Theme.of(context).textTheme.code,
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, size: 18),
                    onPressed: () => setState(() => _filters.removeAt(index)),
                  ),
                );
              }),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Save'),
        ),
      ],
    );
  }

  void _addFilter() {
    final text = _controller.text.trim();
    if (text.isNotEmpty && !_filters.contains(text)) {
      setState(() {
        _filters.add(text);
        _controller.clear();
      });
    }
  }
}

/// Max requests editor dialog
class _MaxRequestsDialog extends StatefulWidget {
  const _MaxRequestsDialog();

  @override
  State<_MaxRequestsDialog> createState() => _MaxRequestsDialogState();
}

class _MaxRequestsDialogState extends State<_MaxRequestsDialog> {
  double _value = 5000;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Max Stored Requests'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Slider(
            value: _value,
            min: 100,
            max: 50000,
            divisions: 50,
            label: _value.round().toString(),
            onChanged: (value) => setState(() => _value = value),
          ),
          Text(
            '${_value.round()} requests',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Older requests will be deleted when limit is reached',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

// ============================================================================
// Settings Provider
// ============================================================================

/// Settings state
class SettingsState {
  final Map<String, dynamic> settings;

  const SettingsState({this.settings = const {}});

  SettingsState copyWith({Map<String, dynamic>? settings}) {
    return SettingsState(settings: settings ?? this.settings);
  }
}

/// Settings controller
class SettingsController extends StateNotifier<SettingsState> {
  SettingsController() : super(const SettingsState());

  void setSetting(String key, dynamic value) {
    state = state.copyWith(
      settings: {...state.settings, key: value},
    );
  }

  dynamic getSetting(String key) {
    return state.settings[key];
  }
}

final settingsControllerProvider =
    StateNotifierProvider<SettingsController, SettingsState>((ref) {
  return SettingsController();
});

final settingProvider = Provider.family<dynamic, String>((ref, key) {
  return ref.watch(settingsControllerProvider).settings[key];
});
