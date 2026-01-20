import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syrah_core/models/models.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Configuration for mitmproxy
class MitmproxyConfig {
  final int proxyPort;
  final int bridgePort;
  final bool sslInsecure;
  /// The host where the WebSocket server is running
  /// For macOS: 'localhost', for Android emulator: '10.0.2.2', for physical devices: computer's IP
  final String bridgeHost;
  /// If true, only connect to WebSocket - don't start mitmdump (for remote/Android use)
  final bool remoteOnly;

  const MitmproxyConfig({
    this.proxyPort = 8888,
    this.bridgePort = 9999,
    this.sslInsecure = false,
    this.bridgeHost = 'localhost',
    this.remoteOnly = false,
  });
}

/// Status of the mitmproxy bridge
enum MitmproxyStatus {
  stopped,
  starting,
  running,
  error,
}

/// State for the mitmproxy bridge
class MitmproxyBridgeState {
  final MitmproxyStatus status;
  final String? error;
  final int activeConnections;
  final int totalFlows;

  const MitmproxyBridgeState({
    this.status = MitmproxyStatus.stopped,
    this.error,
    this.activeConnections = 0,
    this.totalFlows = 0,
  });

  MitmproxyBridgeState copyWith({
    MitmproxyStatus? status,
    String? error,
    int? activeConnections,
    int? totalFlows,
  }) {
    return MitmproxyBridgeState(
      status: status ?? this.status,
      error: error,
      activeConnections: activeConnections ?? this.activeConnections,
      totalFlows: totalFlows ?? this.totalFlows,
    );
  }
}

/// Bridge service that manages mitmproxy subprocess and WebSocket communication
class MitmproxyBridge extends StateNotifier<MitmproxyBridgeState> {
  MitmproxyBridge() : super(const MitmproxyBridgeState());

  Process? _process;
  WebSocketChannel? _channel;
  StreamSubscription? _wsSubscription;
  Timer? _reconnectTimer;
  Timer? _pingTimer;

  final _flowController = StreamController<NetworkFlow>.broadcast();
  final _interceptedController = StreamController<NetworkFlow>.broadcast();

  Stream<NetworkFlow> get flowStream => _flowController.stream;
  Stream<NetworkFlow> get interceptedStream => _interceptedController.stream;

  MitmproxyConfig _config = const MitmproxyConfig();

  /// Start mitmproxy and connect to the bridge
  /// If remoteOnly is true (for Android), only connect to WebSocket without starting mitmdump
  Future<bool> start({MitmproxyConfig? config}) async {
    if (state.status == MitmproxyStatus.running) {
      debugPrint('MitmproxyBridge: Already running');
      return true;
    }

    _config = config ?? _config;
    state = state.copyWith(status: MitmproxyStatus.starting);

    try {
      // Remote-only mode: just connect to WebSocket (for Android connecting to host mitmproxy)
      if (_config.remoteOnly) {
        debugPrint('MitmproxyBridge: Remote-only mode - connecting to existing mitmproxy');
        await _connectWebSocket();
        state = state.copyWith(status: MitmproxyStatus.running);
        return true;
      }

      // Find mitmdump binary
      final mitmdumpPath = await _findMitmdump();
      if (mitmdumpPath == null) {
        throw Exception('mitmdump binary not found');
      }

      // Find syrah_bridge.py addon
      final addonPath = await _findAddon();
      if (addonPath == null) {
        throw Exception('syrah_bridge.py addon not found');
      }

      debugPrint('MitmproxyBridge: Starting mitmdump at $mitmdumpPath');
      debugPrint('MitmproxyBridge: Using addon at $addonPath');

      // Check for Syrah certificate directory
      final home = Platform.environment['HOME'];
      final syrahCertDir = '$home/.syrah';
      final syrahCertExists = await Directory(syrahCertDir).exists() &&
          await File('$syrahCertDir/mitmproxy-ca.pem').exists();

      // Build command arguments
      final args = [
        '-s', addonPath,
        '--listen-port', _config.proxyPort.toString(),
        '--set', 'syrah_port=${_config.bridgePort}',
        '--set', 'block_global=false',
        '--set', 'flow_detail=0', // Reduce console output
      ];

      // Use SyrahProxy certificate if available
      if (syrahCertExists) {
        args.addAll(['--set', 'confdir=$syrahCertDir']);
        debugPrint('MitmproxyBridge: Using SyrahProxy CA from $syrahCertDir');
      } else {
        debugPrint('MitmproxyBridge: Using default mitmproxy CA (generate SyrahProxy cert for custom branding)');
      }

      if (_config.sslInsecure) {
        args.add('--ssl-insecure');
      }

      // Start the process
      _process = await Process.start(
        mitmdumpPath,
        args,
        mode: ProcessStartMode.normal,
      );

      // Capture stdout/stderr for debugging
      _process!.stdout.transform(utf8.decoder).listen((data) {
        debugPrint('mitmdump stdout: $data');
      });

      _process!.stderr.transform(utf8.decoder).listen((data) {
        debugPrint('mitmdump stderr: $data');
      });

      // Handle process exit
      _process!.exitCode.then((code) {
        debugPrint('MitmproxyBridge: mitmdump exited with code $code');
        if (state.status == MitmproxyStatus.running) {
          state = state.copyWith(
            status: MitmproxyStatus.error,
            error: 'mitmdump exited unexpectedly (code $code)',
          );
        }
      });

      // Wait a bit for mitmdump to start
      await Future.delayed(const Duration(seconds: 2));

      // Connect to WebSocket
      await _connectWebSocket();

      state = state.copyWith(status: MitmproxyStatus.running);
      return true;
    } catch (e) {
      debugPrint('MitmproxyBridge: Failed to start: $e');
      state = state.copyWith(
        status: MitmproxyStatus.error,
        error: e.toString(),
      );
      return false;
    }
  }

  /// Stop mitmproxy and disconnect
  Future<void> stop() async {
    debugPrint('MitmproxyBridge: Stopping...');

    _pingTimer?.cancel();
    _pingTimer = null;

    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    await _wsSubscription?.cancel();
    _wsSubscription = null;

    await _channel?.sink.close();
    _channel = null;

    _process?.kill();
    _process = null;

    state = state.copyWith(status: MitmproxyStatus.stopped);
    debugPrint('MitmproxyBridge: Stopped');
  }

  /// Connect to the WebSocket server
  Future<void> _connectWebSocket() async {
    final uri = Uri.parse('ws://${_config.bridgeHost}:${_config.bridgePort}');
    debugPrint('MitmproxyBridge: Connecting to $uri');

    try {
      _channel = WebSocketChannel.connect(uri);
      await _channel!.ready;

      _wsSubscription = _channel!.stream.listen(
        _handleMessage,
        onError: (error) {
          debugPrint('MitmproxyBridge: WebSocket error: $error');
          _scheduleReconnect();
        },
        onDone: () {
          debugPrint('MitmproxyBridge: WebSocket closed');
          _scheduleReconnect();
        },
      );

      // Start ping timer
      _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        sendCommand({'command': 'ping'});
      });

      debugPrint('MitmproxyBridge: WebSocket connected');
    } catch (e) {
      debugPrint('MitmproxyBridge: WebSocket connection failed: $e');
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_reconnectTimer != null) return;
    if (state.status != MitmproxyStatus.running) return;

    _reconnectTimer = Timer(const Duration(seconds: 2), () async {
      _reconnectTimer = null;
      if (state.status == MitmproxyStatus.running) {
        await _connectWebSocket();
      }
    });
  }

  void _handleMessage(dynamic message) {
    try {
      debugPrint('MitmproxyBridge: Received message: ${message.toString().substring(0, message.toString().length > 200 ? 200 : message.toString().length)}...');
      final data = jsonDecode(message as String) as Map<String, dynamic>;
      final type = data['type'] as String?;

      switch (type) {
        case 'flow':
          debugPrint('MitmproxyBridge: Processing flow event');
          _handleFlowEvent(data);
          break;
        case 'pong':
          // Ping response, ignore
          break;
        default:
          debugPrint('MitmproxyBridge: Unknown message type: $type');
      }
    } catch (e) {
      debugPrint('MitmproxyBridge: Error parsing message: $e');
    }
  }

  void _handleFlowEvent(Map<String, dynamic> data) {
    try {
      final flow = _parseFlow(data);
      debugPrint('MitmproxyBridge: Parsed flow - ${flow.request.method.name} ${flow.request.url}');
      state = state.copyWith(totalFlows: state.totalFlows + 1);

      if (data['intercepted'] == true) {
        debugPrint('MitmproxyBridge: Flow intercepted, adding to intercepted stream');
        _interceptedController.add(flow);
      }

      debugPrint('MitmproxyBridge: Adding flow to stream (total: ${state.totalFlows})');
      _flowController.add(flow);
    } catch (e, stackTrace) {
      debugPrint('MitmproxyBridge: Error parsing flow: $e');
      debugPrint('MitmproxyBridge: Stack trace: $stackTrace');
    }
  }

  NetworkFlow _parseFlow(Map<String, dynamic> data) {
    final requestData = data['request'] as Map<String, dynamic>;
    final responseData = data['response'] as Map<String, dynamic>?;
    final flowId = data['id'] as String;
    final now = DateTime.now();

    // Parse URL components
    final url = requestData['url'] as String;
    final uri = Uri.tryParse(url) ?? Uri.parse('http://unknown');

    final request = HttpRequest(
      id: flowId,
      method: HttpMethodExtension.fromString(requestData['method'] as String? ?? 'GET'),
      url: url,
      scheme: uri.scheme.isEmpty ? 'http' : uri.scheme,
      host: requestData['host'] as String? ?? uri.host,
      port: requestData['port'] as int? ?? uri.port,
      path: requestData['path'] as String? ?? uri.path,
      queryString: uri.query.isEmpty ? null : uri.query,
      headers: Map<String, String>.from(requestData['headers'] as Map? ?? {}),
      bodyText: requestData['body'] as String?,
      contentLength: requestData['contentLength'] as int? ?? 0,
      timestamp: _parseTimestamp(requestData['timestampStart']),
      isSecure: uri.scheme == 'https',
    );

    HttpResponse? response;
    if (responseData != null && responseData['statusCode'] != null) {
      response = HttpResponse(
        statusCode: responseData['statusCode'] as int,
        statusMessage: responseData['reason'] as String? ?? '',
        headers: Map<String, String>.from(responseData['headers'] as Map? ?? {}),
        bodyText: responseData['body'] as String?,
        contentLength: responseData['contentLength'] as int? ?? 0,
        timestamp: _parseTimestamp(responseData['timestampStart']),
      );
    }

    // Determine flow state
    FlowState flowState;
    if (data['intercepted'] == true) {
      flowState = FlowState.paused;
    } else if (data['error'] != null) {
      flowState = FlowState.failed;
    } else if (response != null) {
      flowState = FlowState.completed;
    } else {
      flowState = FlowState.pending;
    }

    return NetworkFlow(
      id: flowId,
      sessionId: 'default', // TODO: Support multiple sessions
      request: request,
      response: response,
      state: flowState,
      protocol: uri.scheme == 'https' ? ProtocolType.https : ProtocolType.http,
      error: data['error'] as String?,
      createdAt: now,
      updatedAt: now,
    );
  }

  DateTime _parseTimestamp(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is num) {
      // mitmproxy sends timestamps as seconds since epoch (float)
      return DateTime.fromMillisecondsSinceEpoch((value * 1000).toInt());
    }
    return DateTime.now();
  }

  /// Send a command to mitmproxy
  void sendCommand(Map<String, dynamic> command) {
    if (_channel == null) {
      debugPrint('MitmproxyBridge: Cannot send command, not connected');
      return;
    }

    _channel!.sink.add(jsonEncode(command));
  }

  /// Resume an intercepted flow
  void resumeFlow(String flowId, {Map<String, dynamic>? modified}) {
    sendCommand({
      'command': 'resume',
      'flowId': flowId,
      if (modified != null) 'modified': modified,
    });
  }

  /// Kill an intercepted flow
  void killFlow(String flowId) {
    sendCommand({
      'command': 'kill',
      'flowId': flowId,
    });
  }

  /// Update proxy rules
  void updateRules(List<ProxyRule> rules) {
    sendCommand({
      'command': 'updateRules',
      'rules': rules.map((r) => r.toJson()).toList(),
    });
  }

  /// Find the mitmdump binary
  Future<String?> _findMitmdump() async {
    // First, check common system paths for mitmdump (pip/homebrew installed)
    // PATH may not include these in macOS app sandbox
    final commonPaths = [
      '/opt/homebrew/bin/mitmdump',  // Homebrew on Apple Silicon
      '/usr/local/bin/mitmdump',     // Homebrew on Intel / pip
      '/usr/bin/mitmdump',           // System
    ];

    for (final path in commonPaths) {
      if (await File(path).exists()) {
        debugPrint('MitmproxyBridge: Found mitmdump at $path');
        return path;
      }
    }

    // Try using which command as fallback
    try {
      final result = await Process.run('which', ['mitmdump']);
      if (result.exitCode == 0) {
        final path = (result.stdout as String).trim();
        if (path.isNotEmpty && await File(path).exists()) {
          debugPrint('MitmproxyBridge: Found mitmdump via which: $path');
          return path;
        }
      }
    } catch (e) {
      debugPrint('MitmproxyBridge: which command failed: $e');
    }

    // Fallback: Check in app bundle (macOS) - requires bundled Python runtime
    if (Platform.isMacOS) {
      final bundlePath = Platform.resolvedExecutable;
      final appBundle = File(bundlePath).parent.parent;
      final resourcePath = '${appBundle.path}/Resources/mitmdump';

      if (await File(resourcePath).exists()) {
        debugPrint('MitmproxyBridge: Found bundled mitmdump at $resourcePath (may require Python runtime)');
        return resourcePath;
      }

      // Check in development location
      final devPath = await _findDevPath('mitmdump');
      if (devPath != null) {
        debugPrint('MitmproxyBridge: Found dev mitmdump at $devPath');
        return devPath;
      }
    }

    debugPrint('MitmproxyBridge: mitmdump not found!');
    return null;
  }

  /// Find the syrah_bridge.py addon
  Future<String?> _findAddon() async {
    // Check in app bundle (macOS)
    if (Platform.isMacOS) {
      final bundlePath = Platform.resolvedExecutable;
      final appBundle = File(bundlePath).parent.parent;
      final resourcePath = '${appBundle.path}/Resources/syrah_bridge.py';

      if (await File(resourcePath).exists()) {
        debugPrint('MitmproxyBridge: Found addon in app bundle: $resourcePath');
        return resourcePath;
      }

      // Check in development location
      final devPath = await _findDevPath('syrah_bridge.py');
      if (devPath != null) {
        debugPrint('MitmproxyBridge: Found dev addon at $devPath');
        return devPath;
      }
    }

    debugPrint('MitmproxyBridge: Addon not found!');
    return null;
  }

  /// Find file in development paths
  Future<String?> _findDevPath(String filename) async {
    // Get the current directory
    final cwd = Directory.current.path;

    // Common development paths
    final paths = [
      // App bundle resources
      '$cwd/packages/syrah_app/macos/Runner/Resources/$filename',
      '$cwd/macos/Runner/Resources/$filename',
      '$cwd/../syrah_app/macos/Runner/Resources/$filename',
      '$cwd/../../netscope/packages/syrah_app/macos/Runner/Resources/$filename',
      // Syrah bridge package (for syrah_bridge.py)
      '$cwd/packages/syrah_bridge/$filename',
      '$cwd/../syrah_bridge/$filename',
      // Absolute paths for development
      '/Users/benyamin/PycharmProjects/netscope/packages/syrah_bridge/$filename',
      '/Users/benyamin/PycharmProjects/netscope/packages/syrah_app/macos/Runner/Resources/$filename',
    ];

    for (final path in paths) {
      if (await File(path).exists()) {
        debugPrint('MitmproxyBridge: Found $filename at $path');
        return path;
      }
    }

    return null;
  }

  @override
  void dispose() {
    stop();
    _flowController.close();
    _interceptedController.close();
    super.dispose();
  }
}

/// Provider for the mitmproxy bridge
final mitmproxyBridgeProvider =
    StateNotifierProvider<MitmproxyBridge, MitmproxyBridgeState>((ref) {
  return MitmproxyBridge();
});
