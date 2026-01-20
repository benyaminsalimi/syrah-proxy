import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../home_controller.dart';

/// Mobile drawer containing filter options (sidebar content)
class FilterDrawer extends ConsumerStatefulWidget {
  const FilterDrawer({super.key});

  @override
  ConsumerState<FilterDrawer> createState() => _FilterDrawerState();
}

class _FilterDrawerState extends ConsumerState<FilterDrawer> {
  bool _appsExpanded = true;
  bool _domainsExpanded = true;
  String? _selectedApp;
  String? _selectedDomain;

  @override
  Widget build(BuildContext context) {
    final flows = ref.watch(filteredFlowsProvider);
    final isRunning = ref.watch(proxyRunningProvider);
    final proxyAddress = ref.watch(proxyAddressProvider);
    final emulatorAddress = ref.watch(emulatorProxyAddressProvider);
    final flowCount = ref.watch(flowCountProvider);

    // Group by application (using User-Agent as proxy for app identification)
    final appGroups = <String, int>{};
    final domainGroups = <String, int>{};

    for (final flow in flows) {
      final userAgent = flow.request.headers['User-Agent'] ??
          flow.request.headers['user-agent'] ??
          'Unknown';
      final appName = _extractAppName(userAgent);
      appGroups[appName] = (appGroups[appName] ?? 0) + 1;

      final domain = flow.request.host;
      domainGroups[domain] = (domainGroups[domain] ?? 0) + 1;
    }

    final sortedApps = appGroups.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final sortedDomains = domainGroups.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  bottom: BorderSide(color: Theme.of(context).dividerColor),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.primary, AppColors.accent],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.wifi_tethering,
                            color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Syrah',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isRunning
                                        ? AppColors.success
                                        : AppColors.error,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isRunning ? 'Running' : 'Stopped',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (isRunning) ...[
                    const SizedBox(height: 12),
                    _ProxyInfoRow(
                      label: 'Proxy',
                      value: proxyAddress,
                    ),
                    const SizedBox(height: 4),
                    _ProxyInfoRow(
                      label: 'Emulator',
                      value: emulatorAddress,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    '$flowCount requests captured',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondaryLight,
                        ),
                  ),
                ],
              ),
            ),

            // Filter header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    'Filter',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const Spacer(),
                  if (_selectedApp != null || _selectedDomain != null)
                    TextButton(
                      onPressed: _clearFilter,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Clear'),
                    ),
                ],
              ),
            ),

            // Filter content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: [
                  // Applications section
                  _buildSectionHeader(
                    icon: Icons.apps,
                    title: 'Applications',
                    count: sortedApps.length,
                    expanded: _appsExpanded,
                    onTap: () => setState(() => _appsExpanded = !_appsExpanded),
                  ),
                  if (_appsExpanded) ...[
                    if (sortedApps.isEmpty)
                      _buildEmptyState('No applications')
                    else
                      ...sortedApps.map((entry) => _buildFilterItem(
                            name: entry.key,
                            count: entry.value,
                            icon: _getAppIcon(entry.key),
                            selected: _selectedApp == entry.key,
                            onTap: () => _selectApp(entry.key),
                          )),
                  ],

                  const SizedBox(height: 16),

                  // Domains section
                  _buildSectionHeader(
                    icon: Icons.dns,
                    title: 'Domains',
                    count: sortedDomains.length,
                    expanded: _domainsExpanded,
                    onTap: () =>
                        setState(() => _domainsExpanded = !_domainsExpanded),
                  ),
                  if (_domainsExpanded) ...[
                    if (sortedDomains.isEmpty)
                      _buildEmptyState('No domains')
                    else
                      ...sortedDomains.take(20).map((entry) => _buildFilterItem(
                            name: entry.key,
                            count: entry.value,
                            icon: Icons.language,
                            selected: _selectedDomain == entry.key,
                            onTap: () => _selectDomain(entry.key),
                          )),
                    if (sortedDomains.length > 20)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Text(
                          '+ ${sortedDomains.length - 20} more domains',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                  ],
                ],
              ),
            ),

            // Bottom actions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Theme.of(context).dividerColor),
                ),
              ),
              child: Column(
                children: [
                  // Proxy controls
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () =>
                          ref.read(homeControllerProvider.notifier).toggleProxy(),
                      icon: Icon(
                        isRunning ? Icons.stop : Icons.play_arrow,
                        size: 18,
                      ),
                      label: Text(isRunning ? 'Stop Proxy' : 'Start Proxy'),
                      style: FilledButton.styleFrom(
                        backgroundColor:
                            isRunning ? AppColors.error : AppColors.success,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          ref.read(homeControllerProvider.notifier).clearFlows(),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Clear All'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required int count,
    required bool expanded,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Row(
          children: [
            Icon(
              expanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
              size: 20,
              color: AppColors.textSecondaryLight,
            ),
            const SizedBox(width: 8),
            Icon(icon, size: 18, color: AppColors.textSecondaryLight),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '($count)',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterItem({
    required String name,
    required int count,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withOpacity(0.1) : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? AppColors.primary : AppColors.textSecondaryLight,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  color: selected ? AppColors.primary : null,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primary.withOpacity(0.2)
                    : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color:
                      selected ? AppColors.primary : AppColors.textSecondaryLight,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Center(
        child: Text(
          message,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade400,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }

  String _extractAppName(String userAgent) {
    final ua = userAgent.toLowerCase();

    if (ua.contains('discord')) return 'Discord';
    if (ua.contains('slack')) return 'Slack';
    if (ua.contains('teams')) return 'Microsoft Teams';
    if (ua.contains('vscode') || ua.contains('visual studio code')) return 'VS Code';
    if (ua.contains('notion')) return 'Notion';
    if (ua.contains('figma')) return 'Figma';
    if (ua.contains('spotify')) return 'Spotify';
    if (ua.contains('postman')) return 'Postman';
    if (ua.contains('curl')) return 'curl';
    if (ua.contains('axios')) return 'Axios';
    if (ua.contains('python-requests') || ua.contains('python-urllib')) return 'Python';
    if (ua.contains('node-fetch') || ua.contains('node/')) return 'Node.js';
    if (ua.contains('okhttp')) return 'Android App';
    if (ua.contains('alamofire') || ua.contains('cfnetwork')) return 'iOS App';
    if (ua.contains('dart')) return 'Flutter';
    if (ua.contains('edg/') || ua.contains('edge/')) return 'Edge';
    if (ua.contains('chrome') && !ua.contains('chromium')) return 'Chrome';
    if (ua.contains('firefox')) return 'Firefox';
    if (ua.contains('safari') && !ua.contains('chrome')) return 'Safari';
    if (ua.contains('mozilla')) return 'Browser';

    final parts = userAgent.split('/');
    if (parts.isNotEmpty && parts[0].length < 30 && parts[0].trim().isNotEmpty) {
      return parts[0].trim();
    }

    return 'Unknown';
  }

  IconData _getAppIcon(String appName) {
    switch (appName.toLowerCase()) {
      case 'discord':
        return Icons.discord;
      case 'slack':
        return Icons.tag;
      case 'microsoft teams':
        return Icons.groups;
      case 'notion':
        return Icons.note_alt;
      case 'figma':
        return Icons.design_services;
      case 'vs code':
        return Icons.code;
      case 'spotify':
        return Icons.music_note;
      case 'postman':
        return Icons.api;
      case 'curl':
        return Icons.terminal;
      case 'python':
      case 'node.js':
        return Icons.code;
      case 'android app':
        return Icons.android;
      case 'ios app':
        return Icons.phone_iphone;
      case 'flutter':
        return Icons.flutter_dash;
      case 'chrome':
        return Icons.public;
      case 'safari':
        return Icons.explore;
      case 'firefox':
        return Icons.local_fire_department;
      case 'edge':
        return Icons.public;
      case 'browser':
        return Icons.language;
      default:
        return Icons.apps;
    }
  }

  void _selectApp(String app) {
    setState(() {
      if (_selectedApp == app) {
        _selectedApp = null;
      } else {
        _selectedApp = app;
        _selectedDomain = null;
      }
    });
    _applyFilter();
  }

  void _selectDomain(String domain) {
    setState(() {
      if (_selectedDomain == domain) {
        _selectedDomain = null;
      } else {
        _selectedDomain = domain;
        _selectedApp = null;
      }
    });
    _applyFilter();
  }

  void _clearFilter() {
    setState(() {
      _selectedApp = null;
      _selectedDomain = null;
    });
    _applyFilter();
  }

  void _applyFilter() {
    if (_selectedApp != null) {
      ref.read(homeControllerProvider.notifier).setAppFilter(_selectedApp);
    } else if (_selectedDomain != null) {
      ref.read(homeControllerProvider.notifier).setDomainFilter(_selectedDomain);
    } else {
      ref.read(homeControllerProvider.notifier).clearFilters();
    }
  }
}

/// Proxy info row widget
class _ProxyInfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _ProxyInfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondaryLight,
                ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w500,
                ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
