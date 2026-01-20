import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_theme.dart';
import '../../app/router/app_router.dart';
import '../../core/responsive/breakpoints.dart';
import '../../services/certificate_service.dart';
import 'widgets/request_list.dart';
import 'widgets/request_list_item_mobile.dart';
import 'widgets/sidebar.dart';
import 'widgets/filter_drawer.dart';
import '../detail/detail_panel.dart';
import '../settings/settings_screen_new.dart';
import '../composer/request_composer.dart';
import 'home_controller.dart';

/// Main home screen with request list and detail pane
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  double _sidebarWidth = 200;
  double _detailHeight = 300;
  bool _showSidebar = true;
  bool _showDetail = true;

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;

    // Use different layouts based on screen size
    if (isMobile) {
      return _buildMobileLayout();
    }
    return _buildDesktopLayout();
  }

  /// Mobile layout with drawer and single column
  Widget _buildMobileLayout() {
    final isRunning = ref.watch(proxyRunningProvider);
    final flows = ref.watch(filteredFlowsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('SyrahProxy'),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
            tooltip: 'Filter',
          ),
        ),
        actions: [
          // Proxy status indicator
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isRunning
                  ? AppColors.success.withOpacity(0.1)
                  : AppColors.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isRunning ? AppColors.success : AppColors.error,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  isRunning ? 'Running' : 'Stopped',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isRunning ? AppColors.success : AppColors.error,
                  ),
                ),
              ],
            ),
          ),
          // Start/Stop button
          IconButton(
            icon: Icon(
              isRunning ? Icons.stop_circle : Icons.play_circle,
              color: isRunning ? AppColors.error : AppColors.success,
            ),
            onPressed: () =>
                ref.read(homeControllerProvider.notifier).toggleProxy(),
            tooltip: isRunning ? 'Stop Proxy' : 'Start Proxy',
          ),
          // Clear button
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () =>
                ref.read(homeControllerProvider.notifier).clearFlows(),
            tooltip: 'Clear',
          ),
        ],
      ),
      drawer: const FilterDrawer(),
      body: flows.isEmpty
          ? const _MobileEmptyState()
          : ListView.builder(
              itemCount: flows.length,
              itemBuilder: (context, index) {
                final flow = flows[index];
                return RequestListItemMobile(
                  flow: flow,
                  isSelected: false,
                  onTap: () {
                    // Navigate to detail screen
                    context.push(AppRoutes.detailPath(flow.id));
                  },
                );
              },
            ),
    );
  }

  /// Desktop layout with split panes
  Widget _buildDesktopLayout() {
    final isRunning = ref.watch(proxyRunningProvider);
    final isInitialized = ref.watch(proxyInitializedProvider);
    final proxyAddress = ref.watch(proxyAddressProvider);
    final error = ref.watch(proxyErrorProvider);
    final flowCount = ref.watch(flowCountProvider);
    final isSystemProxyEnabled = ref.watch(systemProxyEnabledProvider);
    final activeInterface = ref.watch(activeNetworkInterfaceProvider);

    return Scaffold(
      body: Column(
        children: [
          // Custom toolbar
          _buildToolbar(isRunning, isSystemProxyEnabled, activeInterface),
          const Divider(height: 1),
          // Status bar
          _buildStatusBar(
            isRunning: isRunning,
            isInitialized: isInitialized,
            proxyAddress: proxyAddress,
            error: error,
            flowCount: flowCount,
          ),
          const Divider(height: 1),
          // Main content
          Expanded(
            child: Row(
              children: [
                // Sidebar
                if (_showSidebar) ...[
                  SizedBox(
                    width: _sidebarWidth,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                      ),
                      child: Column(
                        children: [
                          const Expanded(child: Sidebar()),
                          const Divider(height: 1),
                          ListTile(
                            dense: true,
                            leading: const Icon(Icons.settings, size: 18),
                            title: const Text('Settings'),
                            onTap: _openSettings,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Draggable divider for resizing sidebar
                  MouseRegion(
                    cursor: SystemMouseCursors.resizeColumn,
                    child: GestureDetector(
                      onHorizontalDragUpdate: (details) {
                        setState(() {
                          _sidebarWidth = (_sidebarWidth + details.delta.dx)
                              .clamp(150.0, 400.0);
                        });
                      },
                      child: Container(
                        width: 6,
                        color: Theme.of(context).dividerColor,
                        child: Center(
                          child: Container(
                            width: 4,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade400,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                // Request list and detail
                Expanded(
                  child: Column(
                    children: [
                      // Request list
                      const Expanded(
                        child: RequestList(),
                      ),
                      // Detail panel with resizable divider
                      if (_showDetail) ...[
                        // Draggable divider for resizing
                        MouseRegion(
                          cursor: SystemMouseCursors.resizeRow,
                          child: GestureDetector(
                            onVerticalDragUpdate: (details) {
                              setState(() {
                                _detailHeight = (_detailHeight - details.delta.dy)
                                    .clamp(100.0, MediaQuery.of(context).size.height * 0.7);
                              });
                            },
                            child: Container(
                              height: 6,
                              color: Theme.of(context).dividerColor,
                              child: Center(
                                child: Container(
                                  width: 40,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade400,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          height: _detailHeight,
                          child: const DetailPanel(),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(bool isRunning, bool isSystemProxyEnabled, String? activeInterface) {
    // System proxy can only be enabled when proxy is running
    final canEnableSystemProxy = isRunning;

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
          ),
        ),
      ),
      child: Row(
        children: [
          // Toggle sidebar (first)
          IconButton(
            icon: Icon(
              _showSidebar ? Icons.view_sidebar : Icons.view_sidebar_outlined,
              size: 20,
            ),
            onPressed: () => setState(() => _showSidebar = !_showSidebar),
            tooltip: 'Toggle Sidebar',
          ),
          const SizedBox(width: 8),
          // App logo and title
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.asset(
              'assets/icons/syrah_logo.png',
              width: 28,
              height: 28,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'SyrahProxy',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const Spacer(),
          // System Proxy Toggle (macOS only)
          if (Theme.of(context).platform == TargetPlatform.macOS) ...[
            // Trust Certificate button
            Tooltip(
              message: 'Install & trust CA certificate\nRequired for HTTPS inspection',
              child: InkWell(
                onTap: () => CertificateService.showInstallDialog(context),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_user, size: 16, color: Colors.orange.shade700),
                      const SizedBox(width: 6),
                      Text(
                        'Trust Cert',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.orange.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // System Proxy toggle (disabled when proxy not running)
            Tooltip(
              message: !canEnableSystemProxy
                  ? 'Start proxy first to enable system proxy'
                  : (isSystemProxyEnabled
                      ? 'System proxy enabled on ${activeInterface ?? "unknown"}\nClick to disable'
                      : 'Enable system-wide proxy\nCaptures all macOS traffic'),
              child: Opacity(
                opacity: canEnableSystemProxy ? 1.0 : 0.5,
                child: InkWell(
                  onTap: canEnableSystemProxy
                      ? () => ref.read(homeControllerProvider.notifier).toggleSystemProxy()
                      : null,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSystemProxyEnabled
                          ? AppColors.primary.withOpacity(0.1)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSystemProxyEnabled
                            ? AppColors.primary
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isSystemProxyEnabled ? Icons.vpn_lock : Icons.vpn_lock_outlined,
                          size: 16,
                          color: isSystemProxyEnabled ? AppColors.primary : Colors.grey.shade600,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'System Proxy',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSystemProxyEnabled ? FontWeight.w600 : FontWeight.normal,
                            color: isSystemProxyEnabled ? AppColors.primary : Colors.grey.shade700,
                          ),
                        ),
                        if (isSystemProxyEnabled) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          // Start/Stop button
          FilledButton.icon(
            onPressed: () => ref.read(homeControllerProvider.notifier).toggleProxy(),
            icon: Icon(
              isRunning ? Icons.stop : Icons.play_arrow,
              size: 18,
            ),
            label: Text(isRunning ? 'Stop' : 'Start'),
            style: FilledButton.styleFrom(
              backgroundColor: isRunning ? AppColors.error : AppColors.success,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          // Compose new request button
          OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const RequestComposer(),
                ),
              );
            },
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Compose'),
          ),
          const SizedBox(width: 12),
          // Clear button
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            onPressed: () => ref.read(homeControllerProvider.notifier).clearFlows(),
            tooltip: 'Clear',
          ),
          // Filter button
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list, size: 20),
            tooltip: 'Filter',
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text('All')),
              const PopupMenuItem(value: 'errors', child: Text('Errors Only')),
              const PopupMenuItem(value: 'xhr', child: Text('XHR/Fetch')),
            ],
          ),
          // Toggle detail panel
          IconButton(
            icon: Icon(
              _showDetail ? Icons.vertical_split : Icons.horizontal_split,
              size: 20,
            ),
            onPressed: () => setState(() => _showDetail = !_showDetail),
            tooltip: 'Toggle Detail Panel',
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar({
    required bool isRunning,
    required bool isInitialized,
    required String proxyAddress,
    required String? error,
    required int flowCount,
  }) {
    // Extract port from proxyAddress (e.g., "192.168.1.5:8888" -> "8888")
    final port = proxyAddress.contains(':') ? proxyAddress.split(':').last : '8888';
    final networkAddress = proxyAddress;
    final localAddress = '127.0.0.1:$port';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        children: [
          // Status indicator
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isRunning
                  ? AppColors.success
                  : (isInitialized ? AppColors.warning : AppColors.error),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            isRunning
                ? 'Running'
                : (isInitialized ? 'Stopped' : 'Not Initialized'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          // Proxy addresses
          if (isRunning) ...[
            const SizedBox(width: 16),
            const Text('•'),
            const SizedBox(width: 16),
            Text('Local: ', style: Theme.of(context).textTheme.bodySmall),
            InkWell(
              onTap: () => _copyToClipboard(localAddress),
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      localAddress,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                            fontFamily: 'monospace',
                          ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.copy, size: 12, color: AppColors.primary),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Text('Network: ', style: Theme.of(context).textTheme.bodySmall),
            InkWell(
              onTap: () => _copyToClipboard(networkAddress),
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      networkAddress,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.accent,
                            fontFamily: 'monospace',
                          ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.copy, size: 12, color: AppColors.accent),
                  ],
                ),
              ),
            ),
          ],
          const Spacer(),
          // Flow count
          Text(
            '$flowCount flows',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          // Error indicator
          if (error != null) ...[
            const SizedBox(width: 8),
            Tooltip(
              message: error,
              child: Icon(
                Icons.error_outline,
                color: AppColors.error,
                size: 16,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied: $text'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        width: 300,
      ),
    );
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SettingsScreen(),
      ),
    );
  }
}

/// Mobile empty state when no requests captured
class _MobileEmptyState extends StatelessWidget {
  const _MobileEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.wifi_tethering,
                size: 40,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No requests captured',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start the proxy and configure your device\nto capture network traffic',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondaryLight,
                  ),
            ),
            const SizedBox(height: 32),
            Consumer(
              builder: (context, ref, child) {
                final isRunning = ref.watch(proxyRunningProvider);
                final proxyAddress = ref.watch(proxyAddressProvider);

                return Column(
                  children: [
                    if (!isRunning)
                      FilledButton.icon(
                        onPressed: () => ref
                            .read(homeControllerProvider.notifier)
                            .toggleProxy(),
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Start Proxy'),
                      )
                    else ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(context).dividerColor,
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.success,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Proxy Running',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.success,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              proxyAddress,
                              style: Theme.of(context).textTheme.code.copyWith(
                                    fontSize: 14,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Configure your device to use this proxy\nand start browsing',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
