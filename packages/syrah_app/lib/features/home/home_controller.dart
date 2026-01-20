import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syrah_core/models/models.dart';

import '../../services/mitmproxy_bridge.dart';
import '../../services/system_proxy_service.dart';

/// Proxy configuration
class ProxyConfig {
  final int port;
  final String bindAddress;
  final bool enableSslInterception;
  final List<String> bypassHosts;

  const ProxyConfig({
    this.port = 8888,
    this.bindAddress = '0.0.0.0', // Bind to all interfaces for emulator access
    this.enableSslInterception = true,
    this.bypassHosts = const [],
  });
}

/// State for the home screen
class HomeState {
  final List<NetworkFlow> flows;
  final NetworkFlow? selectedFlow;
  final String searchText;
  final String? appFilter;
  final String? domainFilter;
  final bool isProxyRunning;
  final bool isInitialized;
  final String? error;
  final ProxyConfig config;
  final String? localIpAddress;
  final bool isSystemProxyEnabled;
  final String? activeNetworkInterface;
  final Set<String> pinnedApps;
  final Set<String> pinnedDomains;
  final bool showOnlyPinned;

  const HomeState({
    this.flows = const [],
    this.selectedFlow,
    this.searchText = '',
    this.appFilter,
    this.domainFilter,
    this.isProxyRunning = false,
    this.isInitialized = false,
    this.error,
    this.config = const ProxyConfig(),
    this.localIpAddress,
    this.isSystemProxyEnabled = false,
    this.activeNetworkInterface,
    this.pinnedApps = const {},
    this.pinnedDomains = const {},
    this.showOnlyPinned = false,
  });

  HomeState copyWith({
    List<NetworkFlow>? flows,
    NetworkFlow? selectedFlow,
    bool clearSelection = false,
    String? searchText,
    String? appFilter,
    bool clearAppFilter = false,
    String? domainFilter,
    bool clearDomainFilter = false,
    bool? isProxyRunning,
    bool? isInitialized,
    String? error,
    ProxyConfig? config,
    String? localIpAddress,
    bool? isSystemProxyEnabled,
    String? activeNetworkInterface,
    Set<String>? pinnedApps,
    Set<String>? pinnedDomains,
    bool? showOnlyPinned,
  }) {
    return HomeState(
      flows: flows ?? this.flows,
      selectedFlow: clearSelection ? null : (selectedFlow ?? this.selectedFlow),
      searchText: searchText ?? this.searchText,
      appFilter: clearAppFilter ? null : (appFilter ?? this.appFilter),
      domainFilter: clearDomainFilter ? null : (domainFilter ?? this.domainFilter),
      isProxyRunning: isProxyRunning ?? this.isProxyRunning,
      isInitialized: isInitialized ?? this.isInitialized,
      error: error,
      config: config ?? this.config,
      localIpAddress: localIpAddress ?? this.localIpAddress,
      isSystemProxyEnabled: isSystemProxyEnabled ?? this.isSystemProxyEnabled,
      activeNetworkInterface: activeNetworkInterface ?? this.activeNetworkInterface,
      pinnedApps: pinnedApps ?? this.pinnedApps,
      pinnedDomains: pinnedDomains ?? this.pinnedDomains,
      showOnlyPinned: showOnlyPinned ?? this.showOnlyPinned,
    );
  }

  List<NetworkFlow> get filteredFlows {
    var result = flows;

    // Apply "show only pinned" filter first
    if (showOnlyPinned && (pinnedApps.isNotEmpty || pinnedDomains.isNotEmpty)) {
      result = result.where((flow) {
        final userAgent = flow.request.headers['User-Agent'] ??
                          flow.request.headers['user-agent'] ??
                          'Unknown';
        final appName = _extractAppName(userAgent);
        final domain = flow.request.host;
        return pinnedApps.contains(appName) || pinnedDomains.contains(domain);
      }).toList();
    }

    // Apply app filter
    if (appFilter != null) {
      result = result.where((flow) {
        final userAgent = flow.request.headers['User-Agent'] ??
                          flow.request.headers['user-agent'] ??
                          'Unknown';
        final appName = _extractAppName(userAgent);
        return appName == appFilter;
      }).toList();
    }

    // Apply domain filter
    if (domainFilter != null) {
      result = result.where((flow) => flow.request.host == domainFilter).toList();
    }

    // Apply search filter
    if (searchText.isNotEmpty) {
      final lowerSearch = searchText.toLowerCase();
      result = result.where((flow) {
        final url = flow.request.url.toLowerCase();
        final method = flow.request.method.name.toLowerCase();
        final host = flow.request.host.toLowerCase();
        return url.contains(lowerSearch) ||
            method.contains(lowerSearch) ||
            host.contains(lowerSearch);
      }).toList();
    }

    return result;
  }

  static String _extractAppName(String userAgent) {
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

  /// Get the proxy address for configuration
  String get proxyAddress {
    if (localIpAddress != null) {
      return '$localIpAddress:${config.port}';
    }
    return '${config.bindAddress}:${config.port}';
  }

  /// Get the emulator proxy address (Android emulator uses 10.0.2.2 for host)
  String get emulatorProxyAddress => '10.0.2.2:${config.port}';
}

/// Controller for home screen state - now uses mitmproxy via WebSocket
class HomeController extends StateNotifier<HomeState> {
  final MitmproxyBridge _bridge;
  final SystemProxyService _systemProxy = SystemProxyService.instance;

  HomeController(this._bridge) : super(const HomeState()) {
    _getLocalIpAddress();
    _setupBridgeListeners();
    _checkSystemProxyStatus();
  }

  StreamSubscription<NetworkFlow>? _flowSubscription;
  StreamSubscription<NetworkFlow>? _interceptedSubscription;

  /// Get local IP address
  Future<void> _getLocalIpAddress() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );
      for (var interface in interfaces) {
        // Skip loopback and virtual interfaces
        if (interface.name.startsWith('lo') ||
            interface.name.startsWith('vmnet') ||
            interface.name.startsWith('vboxnet')) {
          continue;
        }
        for (var addr in interface.addresses) {
          if (!addr.isLoopback) {
            state = state.copyWith(localIpAddress: addr.address);
            return;
          }
        }
      }
    } catch (e) {
      print('Failed to get local IP: $e');
    }
  }

  void _setupBridgeListeners() {
    _flowSubscription = _bridge.flowStream.listen(_handleFlowEvent);
    _interceptedSubscription = _bridge.interceptedStream.listen(_handleInterceptedFlow);
  }

  /// Handle flow event from mitmproxy
  void _handleFlowEvent(NetworkFlow flow) {
    print('[HomeController] Received flow: ${flow.request.method.name} ${flow.request.url}');
    final existingIndex = state.flows.indexWhere((f) => f.id == flow.id);
    if (existingIndex != -1) {
      // Update existing flow
      print('[HomeController] Updating existing flow at index $existingIndex');
      final newFlows = List<NetworkFlow>.from(state.flows);
      newFlows[existingIndex] = flow;
      state = state.copyWith(
        flows: newFlows,
        selectedFlow: state.selectedFlow?.id == flow.id ? flow : null,
      );
    } else {
      // Add new flow (prepend for newest first)
      print('[HomeController] Adding new flow (total: ${state.flows.length + 1})');
      state = state.copyWith(flows: [flow, ...state.flows]);
    }
  }

  /// Handle intercepted flow (breakpoint hit)
  void _handleInterceptedFlow(NetworkFlow flow) {
    // TODO: Show breakpoint dialog
    print('[HomeController] Breakpoint hit: ${flow.request.url}');
  }

  /// Start the proxy server using mitmproxy
  Future<void> startProxy() async {
    print('[HomeController] startProxy() called');

    try {
      // Detect platform to configure appropriately
      final isAndroid = Platform.isAndroid;

      // For Android: Connect to mitmproxy running on host machine
      // For macOS: Start local mitmdump and connect
      final config = isAndroid
          ? MitmproxyConfig(
              proxyPort: state.config.port,
              bridgePort: 9999,
              bridgeHost: '10.0.2.2', // Android emulator host IP
              remoteOnly: true,       // Don't try to start mitmdump
              sslInsecure: false,
            )
          : MitmproxyConfig(
              proxyPort: state.config.port,
              bridgePort: 9999,
              bridgeHost: 'localhost',
              remoteOnly: false,
              sslInsecure: false,
            );

      print('[HomeController] Using config: bridgeHost=${config.bridgeHost}, remoteOnly=${config.remoteOnly}');

      final success = await _bridge.start(config: config);

      if (success) {
        state = state.copyWith(
          isProxyRunning: true,
          isInitialized: true,
          error: null,
        );
        print('[HomeController] Proxy started on ${state.proxyAddress}');
        print('[HomeController] For Android emulator, use: ${state.emulatorProxyAddress}');
      } else {
        state = state.copyWith(
          error: 'Failed to start mitmproxy',
        );
      }
    } catch (e) {
      print('[HomeController] Exception in startProxy: $e');
      state = state.copyWith(error: 'Start error: $e');
    }
  }

  /// Stop the proxy server
  Future<void> stopProxy() async {
    try {
      // Disable system proxy if it's enabled
      if (state.isSystemProxyEnabled) {
        await disableSystemProxy();
      }
      await _bridge.stop();
      state = state.copyWith(isProxyRunning: false, error: null);
    } catch (e) {
      state = state.copyWith(error: 'Stop error: $e');
    }
  }

  /// Toggle proxy running state
  Future<void> toggleProxy() async {
    if (state.isProxyRunning) {
      await stopProxy();
    } else {
      await startProxy();
    }
  }

  /// Check current system proxy status
  Future<void> _checkSystemProxyStatus() async {
    final status = await _systemProxy.getProxyStatus();
    final interface = await _systemProxy.getActiveNetworkInterface();

    state = state.copyWith(
      isSystemProxyEnabled: status['isOurProxy'] == true,
      activeNetworkInterface: interface,
    );
  }

  /// Enable system-wide proxy (routes all macOS traffic through mitmproxy)
  Future<bool> enableSystemProxy() async {
    print('[HomeController] Enabling system proxy...');

    final success = await _systemProxy.enableSystemProxy(
      host: '127.0.0.1',
      port: state.config.port,
    );

    if (success) {
      state = state.copyWith(
        isSystemProxyEnabled: true,
        activeNetworkInterface: _systemProxy.activeInterface,
      );
      print('[HomeController] System proxy enabled on ${_systemProxy.activeInterface}');
    } else {
      state = state.copyWith(error: 'Failed to enable system proxy');
    }

    return success;
  }

  /// Disable system-wide proxy and restore original settings
  Future<bool> disableSystemProxy() async {
    print('[HomeController] Disabling system proxy...');

    final success = await _systemProxy.disableSystemProxy();

    if (success) {
      state = state.copyWith(
        isSystemProxyEnabled: false,
      );
      print('[HomeController] System proxy disabled');
    }

    return success;
  }

  /// Toggle system proxy on/off
  Future<void> toggleSystemProxy() async {
    if (state.isSystemProxyEnabled) {
      await disableSystemProxy();
    } else {
      await enableSystemProxy();
    }
  }

  /// Clear all captured flows
  void clearFlows() {
    state = state.copyWith(flows: [], clearSelection: true);
  }

  /// Set search text
  void setSearchText(String text) {
    state = state.copyWith(searchText: text);
  }

  /// Set app filter
  void setAppFilter(String? app) {
    state = state.copyWith(
      appFilter: app,
      clearAppFilter: app == null,
      clearDomainFilter: true, // Clear domain filter when setting app
    );
  }

  /// Set domain filter
  void setDomainFilter(String? domain) {
    state = state.copyWith(
      domainFilter: domain,
      clearDomainFilter: domain == null,
      clearAppFilter: true, // Clear app filter when setting domain
    );
  }

  /// Clear all filters
  void clearFilters() {
    state = state.copyWith(
      clearAppFilter: true,
      clearDomainFilter: true,
    );
  }

  /// Toggle pin status for an app
  void togglePinApp(String appName) {
    final newPinnedApps = Set<String>.from(state.pinnedApps);
    if (newPinnedApps.contains(appName)) {
      newPinnedApps.remove(appName);
    } else {
      newPinnedApps.add(appName);
    }
    state = state.copyWith(pinnedApps: newPinnedApps);
  }

  /// Toggle pin status for a domain
  void togglePinDomain(String domain) {
    final newPinnedDomains = Set<String>.from(state.pinnedDomains);
    if (newPinnedDomains.contains(domain)) {
      newPinnedDomains.remove(domain);
    } else {
      newPinnedDomains.add(domain);
    }
    state = state.copyWith(pinnedDomains: newPinnedDomains);
  }

  /// Check if an app is pinned
  bool isAppPinned(String appName) => state.pinnedApps.contains(appName);

  /// Check if a domain is pinned
  bool isDomainPinned(String domain) => state.pinnedDomains.contains(domain);

  /// Toggle "show only pinned" mode
  void toggleShowOnlyPinned() {
    state = state.copyWith(showOnlyPinned: !state.showOnlyPinned);
  }

  /// Set "show only pinned" mode
  void setShowOnlyPinned(bool value) {
    state = state.copyWith(showOnlyPinned: value);
  }

  /// Clear all pins
  void clearPins() {
    state = state.copyWith(
      pinnedApps: const {},
      pinnedDomains: const {},
      showOnlyPinned: false,
    );
  }

  /// Select a flow
  void selectFlow(NetworkFlow flow) {
    state = state.copyWith(selectedFlow: flow);
  }

  /// Clear selection
  void clearSelection() {
    state = state.copyWith(clearSelection: true);
  }

  /// Mark/star a flow
  void toggleMark(String flowId) {
    final index = state.flows.indexWhere((f) => f.id == flowId);
    if (index != -1) {
      final newFlows = List<NetworkFlow>.from(state.flows);
      final flow = newFlows[index];
      newFlows[index] = flow.copyWith(isMarked: !flow.isMarked);
      state = state.copyWith(flows: newFlows);
    }
  }

  /// Resume an intercepted flow
  void resumeFlow(String flowId, {Map<String, dynamic>? modified}) {
    _bridge.resumeFlow(flowId, modified: modified);
  }

  /// Kill an intercepted flow
  void killFlow(String flowId) {
    _bridge.killFlow(flowId);
  }

  /// Update proxy rules
  void updateRules(List<ProxyRule> rules) {
    _bridge.updateRules(rules);
  }

  /// Export mitmproxy CA certificate path
  Future<String?> getCertificatePath() async {
    // mitmproxy stores its CA at ~/.mitmproxy/mitmproxy-ca-cert.pem
    final home = Platform.environment['HOME'];
    if (home != null) {
      final certPath = '$home/.mitmproxy/mitmproxy-ca-cert.pem';
      if (await File(certPath).exists()) {
        return certPath;
      }
    }
    return null;
  }

  /// Cleanup when app is closing - ensures system proxy is disabled
  Future<void> cleanup() async {
    if (state.isSystemProxyEnabled) {
      await disableSystemProxy();
    }
    if (state.isProxyRunning) {
      await _bridge.stop();
    }
  }

  @override
  void dispose() {
    // Note: cleanup() should be called before dispose for async operations
    _flowSubscription?.cancel();
    _interceptedSubscription?.cancel();
    super.dispose();
  }
}

/// Provider for mitmproxy bridge
final mitmproxyBridgeProvider =
    StateNotifierProvider<MitmproxyBridge, MitmproxyBridgeState>((ref) {
  return MitmproxyBridge();
});

/// Provider for home controller
final homeControllerProvider =
    StateNotifierProvider<HomeController, HomeState>((ref) {
  final bridge = ref.watch(mitmproxyBridgeProvider.notifier);
  final controller = HomeController(bridge);
  return controller;
});

/// Provider for proxy running state
final proxyRunningProvider = Provider<bool>((ref) {
  return ref.watch(homeControllerProvider).isProxyRunning;
});

/// Provider for proxy initialized state
final proxyInitializedProvider = Provider<bool>((ref) {
  return ref.watch(homeControllerProvider).isInitialized;
});

/// Provider for filtered flows
final filteredFlowsProvider = Provider<List<NetworkFlow>>((ref) {
  return ref.watch(homeControllerProvider).filteredFlows;
});

/// Provider for selected flow
final selectedFlowProvider = Provider<NetworkFlow?>((ref) {
  return ref.watch(homeControllerProvider).selectedFlow;
});

/// Provider for flow count
final flowCountProvider = Provider<int>((ref) {
  return ref.watch(homeControllerProvider).flows.length;
});

/// Provider for proxy address
final proxyAddressProvider = Provider<String>((ref) {
  return ref.watch(homeControllerProvider).proxyAddress;
});

/// Provider for emulator proxy address
final emulatorProxyAddressProvider = Provider<String>((ref) {
  return ref.watch(homeControllerProvider).emulatorProxyAddress;
});

/// Provider for error message
final proxyErrorProvider = Provider<String?>((ref) {
  return ref.watch(homeControllerProvider).error;
});

/// Provider for system proxy enabled state
final systemProxyEnabledProvider = Provider<bool>((ref) {
  return ref.watch(homeControllerProvider).isSystemProxyEnabled;
});

/// Provider for active network interface
final activeNetworkInterfaceProvider = Provider<String?>((ref) {
  return ref.watch(homeControllerProvider).activeNetworkInterface;
});

/// Provider for pinned apps
final pinnedAppsProvider = Provider<Set<String>>((ref) {
  return ref.watch(homeControllerProvider).pinnedApps;
});

/// Provider for pinned domains
final pinnedDomainsProvider = Provider<Set<String>>((ref) {
  return ref.watch(homeControllerProvider).pinnedDomains;
});

/// Provider for show only pinned mode
final showOnlyPinnedProvider = Provider<bool>((ref) {
  return ref.watch(homeControllerProvider).showOnlyPinned;
});

/// Provider for total pinned count
final pinnedCountProvider = Provider<int>((ref) {
  final state = ref.watch(homeControllerProvider);
  return state.pinnedApps.length + state.pinnedDomains.length;
});
