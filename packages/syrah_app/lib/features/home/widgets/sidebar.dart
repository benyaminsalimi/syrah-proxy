import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../home_controller.dart';

/// Sidebar showing applications and domains for filtering
class Sidebar extends ConsumerStatefulWidget {
  const Sidebar({super.key});

  @override
  ConsumerState<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends ConsumerState<Sidebar> {
  bool _appsExpanded = true;
  bool _domainsExpanded = true;
  String? _selectedApp;
  String? _selectedDomain;

  @override
  Widget build(BuildContext context) {
    final flows = ref.watch(filteredFlowsProvider);
    final pinnedApps = ref.watch(pinnedAppsProvider);
    final pinnedDomains = ref.watch(pinnedDomainsProvider);
    final showOnlyPinned = ref.watch(showOnlyPinnedProvider);
    final pinnedCount = ref.watch(pinnedCountProvider);

    // Group by application (using User-Agent as proxy for app identification)
    final appGroups = <String, int>{};
    final domainGroups = <String, int>{};

    for (final flow in flows) {
      // Extract app from User-Agent header
      final userAgent = flow.request.headers['User-Agent'] ??
                        flow.request.headers['user-agent'] ??
                        'Unknown';
      final appName = _extractAppName(userAgent);
      appGroups[appName] = (appGroups[appName] ?? 0) + 1;

      // Group by domain
      final domain = flow.request.host;
      domainGroups[domain] = (domainGroups[domain] ?? 0) + 1;
    }

    // Sort by count, but pinned items first
    final sortedApps = appGroups.entries.toList()
      ..sort((a, b) {
        final aPinned = pinnedApps.contains(a.key);
        final bPinned = pinnedApps.contains(b.key);
        if (aPinned != bPinned) return aPinned ? -1 : 1;
        return b.value.compareTo(a.value);
      });
    final sortedDomains = domainGroups.entries.toList()
      ..sort((a, b) {
        final aPinned = pinnedDomains.contains(a.key);
        final bPinned = pinnedDomains.contains(b.key);
        if (aPinned != bPinned) return aPinned ? -1 : 1;
        return b.value.compareTo(a.value);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with "Only Pinned" toggle
        Padding(
          padding: const EdgeInsets.all(12),
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
                  child: const Text('Clear', style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
        ),
        // "Only Pinned" toggle row
        if (pinnedCount > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: InkWell(
              onTap: () {
                ref.read(homeControllerProvider.notifier).toggleShowOnlyPinned();
              },
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: showOnlyPinned
                      ? AppColors.primary.withOpacity(0.1)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                  border: showOnlyPinned
                      ? Border.all(color: AppColors.primary.withOpacity(0.3))
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.push_pin,
                      size: 14,
                      color: showOnlyPinned ? AppColors.primary : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Only Pinned',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: showOnlyPinned ? FontWeight.w600 : FontWeight.normal,
                        color: showOnlyPinned ? AppColors.primary : Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: showOnlyPinned
                            ? AppColors.primary
                            : Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$pinnedCount',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        const Divider(height: 1),

        // Content
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
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
                  ...sortedApps.map((entry) => _buildAppItem(
                    name: entry.key,
                    count: entry.value,
                    selected: _selectedApp == entry.key,
                    pinned: pinnedApps.contains(entry.key),
                    onTap: () => _selectApp(entry.key),
                    onPinTap: () => _togglePinApp(entry.key),
                  )),
              ],

              const SizedBox(height: 8),

              // Domains section
              _buildSectionHeader(
                icon: Icons.dns,
                title: 'Domains',
                count: sortedDomains.length,
                expanded: _domainsExpanded,
                onTap: () => setState(() => _domainsExpanded = !_domainsExpanded),
              ),
              if (_domainsExpanded) ...[
                if (sortedDomains.isEmpty)
                  _buildEmptyState('No domains')
                else
                  ...sortedDomains.map((entry) => _buildDomainItem(
                    domain: entry.key,
                    count: entry.value,
                    selected: _selectedDomain == entry.key,
                    pinned: pinnedDomains.contains(entry.key),
                    onTap: () => _selectDomain(entry.key),
                    onPinTap: () => _togglePinDomain(entry.key),
                  )),
              ],
            ],
          ),
        ),
      ],
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(
              expanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
              size: 18,
              color: AppColors.textSecondaryLight,
            ),
            const SizedBox(width: 4),
            Icon(icon, size: 16, color: AppColors.textSecondaryLight),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '($count)',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppItem({
    required String name,
    required int count,
    required bool selected,
    required bool pinned,
    required VoidCallback onTap,
    required VoidCallback onPinTap,
  }) {
    final icon = _getAppIcon(name);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withOpacity(0.1) : null,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            // Pin button
            GestureDetector(
              onTap: onPinTap,
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Icon(
                  pinned ? Icons.push_pin : Icons.push_pin_outlined,
                  size: 14,
                  color: pinned ? AppColors.primary : Colors.grey.shade400,
                ),
              ),
            ),
            Icon(icon, size: 16, color: selected ? AppColors.primary : AppColors.textSecondaryLight),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected || pinned ? FontWeight.w600 : FontWeight.normal,
                  color: selected ? AppColors.primary : (pinned ? AppColors.primary.withOpacity(0.8) : null),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primary.withOpacity(0.2)
                    : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: selected ? AppColors.primary : AppColors.textSecondaryLight,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDomainItem({
    required String domain,
    required int count,
    required bool selected,
    required bool pinned,
    required VoidCallback onTap,
    required VoidCallback onPinTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withOpacity(0.1) : null,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            // Pin button
            GestureDetector(
              onTap: onPinTap,
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Icon(
                  pinned ? Icons.push_pin : Icons.push_pin_outlined,
                  size: 14,
                  color: pinned ? AppColors.primary : Colors.grey.shade400,
                ),
              ),
            ),
            // Favicon
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.network(
                'https://www.google.com/s2/favicons?domain=$domain&sz=32',
                width: 16,
                height: 16,
                errorBuilder: (context, error, stackTrace) => Icon(
                  Icons.language,
                  size: 16,
                  color: selected ? AppColors.primary : AppColors.textSecondaryLight,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                domain,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected || pinned ? FontWeight.w600 : FontWeight.normal,
                  color: selected ? AppColors.primary : (pinned ? AppColors.primary.withOpacity(0.8) : null),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primary.withOpacity(0.2)
                    : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: selected ? AppColors.primary : AppColors.textSecondaryLight,
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Center(
        child: Text(
          message,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade400,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }

  String _extractAppName(String userAgent) {
    final ua = userAgent.toLowerCase();

    // Desktop Apps (Electron-based)
    if (ua.contains('discord')) return 'Discord';
    if (ua.contains('slack')) return 'Slack';
    if (ua.contains('teams')) return 'Microsoft Teams';
    if (ua.contains('vscode') || ua.contains('visual studio code')) return 'VS Code';
    if (ua.contains('notion')) return 'Notion';
    if (ua.contains('figma')) return 'Figma';
    if (ua.contains('spotify')) return 'Spotify';
    if (ua.contains('whatsapp')) return 'WhatsApp';
    if (ua.contains('telegram')) return 'Telegram';
    if (ua.contains('signal')) return 'Signal';
    if (ua.contains('zoom')) return 'Zoom';
    if (ua.contains('skype')) return 'Skype';
    if (ua.contains('postman')) return 'Postman';
    if (ua.contains('insomnia')) return 'Insomnia';
    if (ua.contains('httpie')) return 'HTTPie';
    if (ua.contains('1password')) return '1Password';
    if (ua.contains('bitwarden')) return 'Bitwarden';
    if (ua.contains('dropbox')) return 'Dropbox';
    if (ua.contains('google drive') || ua.contains('gdrive')) return 'Google Drive';
    if (ua.contains('onedrive')) return 'OneDrive';
    if (ua.contains('icloud')) return 'iCloud';

    // Development Tools
    if (ua.contains('curl')) return 'curl';
    if (ua.contains('wget')) return 'wget';
    if (ua.contains('axios')) return 'Axios';
    if (ua.contains('python-requests') || ua.contains('python-urllib')) return 'Python';
    if (ua.contains('node-fetch') || ua.contains('node/')) return 'Node.js';
    if (ua.contains('go-http-client')) return 'Go';
    if (ua.contains('okhttp')) return 'Android App';
    if (ua.contains('alamofire') || ua.contains('cfnetwork')) return 'iOS App';
    if (ua.contains('dart')) return 'Flutter';
    if (ua.contains('java/') || ua.contains('java-http')) return 'Java';
    if (ua.contains('ruby')) return 'Ruby';
    if (ua.contains('php')) return 'PHP';
    if (ua.contains('rust')) return 'Rust';

    // Browsers
    if (ua.contains('edg/') || ua.contains('edge/')) return 'Edge';
    if (ua.contains('opr/') || ua.contains('opera')) return 'Opera';
    if (ua.contains('brave')) return 'Brave';
    if (ua.contains('vivaldi')) return 'Vivaldi';
    if (ua.contains('arc/')) return 'Arc';
    if (ua.contains('chrome') && !ua.contains('chromium')) return 'Chrome';
    if (ua.contains('chromium')) return 'Chromium';
    if (ua.contains('firefox')) return 'Firefox';
    if (ua.contains('safari') && !ua.contains('chrome')) return 'Safari';

    // Generic Electron app
    if (ua.contains('electron')) return 'Electron App';

    // macOS system
    if (ua.contains('macos') || ua.contains('mac os') || ua.contains('darwin')) return 'macOS';

    // Generic browser
    if (ua.contains('mozilla')) return 'Browser';

    // Try to extract first word
    final parts = userAgent.split('/');
    if (parts.isNotEmpty && parts[0].length < 30 && parts[0].trim().isNotEmpty) {
      return parts[0].trim();
    }

    return 'Unknown';
  }

  IconData _getAppIcon(String appName) {
    switch (appName.toLowerCase()) {
      // Communication Apps
      case 'discord':
        return Icons.discord;
      case 'slack':
        return Icons.tag;
      case 'microsoft teams':
        return Icons.groups;
      case 'whatsapp':
      case 'telegram':
      case 'signal':
        return Icons.chat;
      case 'zoom':
      case 'skype':
        return Icons.video_call;

      // Productivity
      case 'notion':
        return Icons.note_alt;
      case 'figma':
        return Icons.design_services;
      case 'vs code':
        return Icons.code;
      case 'spotify':
        return Icons.music_note;

      // Cloud Storage
      case 'dropbox':
      case 'google drive':
      case 'onedrive':
      case 'icloud':
        return Icons.cloud;

      // Security
      case '1password':
      case 'bitwarden':
        return Icons.password;

      // Development CLI
      case 'curl':
      case 'wget':
        return Icons.terminal;
      case 'postman':
      case 'insomnia':
      case 'httpie':
        return Icons.api;

      // Programming Languages
      case 'python':
        return Icons.code;
      case 'node.js':
        return Icons.javascript;
      case 'go':
      case 'rust':
      case 'java':
      case 'ruby':
      case 'php':
        return Icons.code;
      case 'axios':
        return Icons.http;

      // Mobile
      case 'android app':
        return Icons.android;
      case 'ios app':
        return Icons.phone_iphone;
      case 'flutter':
        return Icons.flutter_dash;

      // Browsers
      case 'chrome':
      case 'chromium':
        return Icons.public;
      case 'safari':
        return Icons.explore;
      case 'firefox':
        return Icons.local_fire_department;
      case 'edge':
        return Icons.public;
      case 'opera':
      case 'brave':
      case 'vivaldi':
      case 'arc':
        return Icons.public;
      case 'browser':
        return Icons.language;

      // Generic
      case 'electron app':
        return Icons.desktop_windows;
      case 'macos':
        return Icons.laptop_mac;
      case 'unknown':
        return Icons.help_outline;
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

  void _togglePinApp(String appName) {
    ref.read(homeControllerProvider.notifier).togglePinApp(appName);
  }

  void _togglePinDomain(String domain) {
    ref.read(homeControllerProvider.notifier).togglePinDomain(domain);
  }
}
