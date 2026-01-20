import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Android proxy plugin for Syrah
class SyrahProxyAndroid {
  static const _methodChannel = MethodChannel('dev.syrah.proxy.android/methods');
  static const _eventChannel = EventChannel('dev.syrah.proxy.android/flows');
  static const _statusChannel = EventChannel('dev.syrah.proxy.android/status');

  static SyrahProxyAndroid? _instance;

  /// Singleton instance
  static SyrahProxyAndroid get instance {
    _instance ??= SyrahProxyAndroid._();
    return _instance!;
  }

  SyrahProxyAndroid._();

  StreamSubscription<dynamic>? _flowSubscription;
  StreamSubscription<dynamic>? _statusSubscription;

  final _flowController = StreamController<Map<String, dynamic>>.broadcast();
  final _statusController = StreamController<Map<String, dynamic>>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  /// Stream of network flows
  Stream<Map<String, dynamic>> get flowStream => _flowController.stream;

  /// Stream of proxy status updates
  Stream<Map<String, dynamic>> get statusStream => _statusController.stream;

  /// Stream of error messages
  Stream<String> get errorStream => _errorController.stream;

  /// Initialize the proxy engine
  Future<bool> initialize() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('initialize');
      if (result == true) {
        _setupEventListeners();
      }
      return result ?? false;
    } on PlatformException catch (e) {
      _errorController.add('Failed to initialize: ${e.message}');
      return false;
    }
  }

  void _setupEventListeners() {
    _flowSubscription?.cancel();
    _flowSubscription = _eventChannel.receiveBroadcastStream().listen(
      (event) {
        if (event is Map) {
          _flowController.add(Map<String, dynamic>.from(event));
        }
      },
      onError: (error) {
        _errorController.add('Flow stream error: $error');
      },
    );

    _statusSubscription?.cancel();
    _statusSubscription = _statusChannel.receiveBroadcastStream().listen(
      (event) {
        if (event is Map) {
          _statusController.add(Map<String, dynamic>.from(event));
        }
      },
      onError: (error) {
        _errorController.add('Status stream error: $error');
      },
    );
  }

  /// Start the proxy server
  Future<bool> startProxy({
    int port = 8888,
    bool enableSslInterception = true,
    List<String> bypassApps = const [],
  }) async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('startProxy', {
        'port': port,
        'enableSslInterception': enableSslInterception,
        'bypassApps': bypassApps,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      _errorController.add('Failed to start proxy: ${e.message}');
      return false;
    }
  }

  /// Stop the proxy server
  Future<bool> stopProxy() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('stopProxy');
      return result ?? false;
    } on PlatformException catch (e) {
      _errorController.add('Failed to stop proxy: ${e.message}');
      return false;
    }
  }

  /// Get current proxy status
  Future<Map<String, dynamic>?> getProxyStatus() async {
    try {
      final result = await _methodChannel.invokeMethod<Map>('getProxyStatus');
      return result != null ? Map<String, dynamic>.from(result) : null;
    } on PlatformException catch (e) {
      _errorController.add('Failed to get status: ${e.message}');
      return null;
    }
  }

  /// Get the root CA certificate info
  Future<Map<String, dynamic>?> getRootCertificate() async {
    try {
      final result = await _methodChannel.invokeMethod<Map>('getRootCertificate');
      return result != null ? Map<String, dynamic>.from(result) : null;
    } on PlatformException catch (e) {
      _errorController.add('Failed to get certificate: ${e.message}');
      return null;
    }
  }

  /// Export root CA certificate
  Future<Uint8List?> exportRootCertificate({String format = 'pem'}) async {
    try {
      final result = await _methodChannel.invokeMethod<Uint8List>(
        'exportRootCertificate',
        {'format': format},
      );
      return result;
    } on PlatformException catch (e) {
      _errorController.add('Failed to export certificate: ${e.message}');
      return null;
    }
  }

  /// Set proxy rules
  Future<bool> setRules(List<Map<String, dynamic>> rules) async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('setRules', {
        'rules': rules,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      _errorController.add('Failed to set rules: ${e.message}');
      return false;
    }
  }

  /// Pause a flow at breakpoint
  Future<bool> pauseFlow(String flowId) async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('pauseFlow', {
        'flowId': flowId,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      _errorController.add('Failed to pause flow: ${e.message}');
      return false;
    }
  }

  /// Resume a paused flow
  Future<bool> resumeFlow(
    String flowId, {
    Map<String, dynamic>? modifiedRequest,
    Map<String, dynamic>? modifiedResponse,
  }) async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('resumeFlow', {
        'flowId': flowId,
        if (modifiedRequest != null) 'modifiedRequest': modifiedRequest,
        if (modifiedResponse != null) 'modifiedResponse': modifiedResponse,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      _errorController.add('Failed to resume flow: ${e.message}');
      return false;
    }
  }

  /// Abort a flow
  Future<bool> abortFlow(String flowId) async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('abortFlow', {
        'flowId': flowId,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      _errorController.add('Failed to abort flow: ${e.message}');
      return false;
    }
  }

  /// Set network throttling
  Future<bool> setThrottling({
    int downloadBytesPerSecond = 0,
    int uploadBytesPerSecond = 0,
    int latencyMs = 0,
    double packetLossPercent = 0,
  }) async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('setThrottling', {
        'downloadBytesPerSecond': downloadBytesPerSecond,
        'uploadBytesPerSecond': uploadBytesPerSecond,
        'latencyMs': latencyMs,
        'packetLossPercent': packetLossPercent,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      _errorController.add('Failed to set throttling: ${e.message}');
      return false;
    }
  }

  /// Disable network throttling
  Future<bool> disableThrottling() async {
    return setThrottling();
  }

  /// Request VPN permission
  Future<bool> requestVpnPermission() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('requestVpnPermission');
      return result ?? false;
    } on PlatformException catch (e) {
      _errorController.add('Failed to request VPN permission: ${e.message}');
      return false;
    }
  }

  /// Start VPN service
  Future<bool> startVpnService() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('startVpnService');
      return result ?? false;
    } on PlatformException catch (e) {
      _errorController.add('Failed to start VPN: ${e.message}');
      return false;
    }
  }

  /// Stop VPN service
  Future<bool> stopVpnService() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('stopVpnService');
      return result ?? false;
    } on PlatformException catch (e) {
      _errorController.add('Failed to stop VPN: ${e.message}');
      return false;
    }
  }

  /// Set apps to bypass VPN
  Future<bool> setBypassApps(List<String> packageNames) async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('setBypassApps', {
        'packageNames': packageNames,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      _errorController.add('Failed to set bypass apps: ${e.message}');
      return false;
    }
  }

  /// Get platform version
  Future<String?> getPlatformVersion() async {
    try {
      final result = await _methodChannel.invokeMethod<String>('getPlatformVersion');
      return result;
    } on PlatformException catch (e) {
      _errorController.add('Failed to get version: ${e.message}');
      return null;
    }
  }

  /// Dispose of resources
  void dispose() {
    _flowSubscription?.cancel();
    _statusSubscription?.cancel();
    _flowController.close();
    _statusController.close();
    _errorController.close();
  }
}
