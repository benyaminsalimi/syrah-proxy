import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Android proxy plugin for NetScope
class NetScopeProxyAndroid {
  static const _methodChannel = MethodChannel('com.netscope.proxy.android/methods');
  static const _eventChannel = EventChannel('com.netscope.proxy.android/flows');
  static const _statusChannel = EventChannel('com.netscope.proxy.android/status');

  static NetScopeProxyAndroid? _instance;

  /// Singleton instance
  static NetScopeProxyAndroid get instance {
    _instance ??= NetScopeProxyAndroid._();
    return _instance!;
  }

  NetScopeProxyAndroid._();

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

  /// Check if VPN permission is granted
  Future<bool> hasVpnPermission() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('hasVpnPermission');
      return result ?? false;
    } on PlatformException catch (e) {
      _errorController.add('Failed to check VPN permission: ${e.message}');
      return false;
    }
  }

  /// Start the VPN proxy service
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

  /// Stop the VPN proxy service
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

  /// Generate or get the root CA certificate
  Future<Map<String, dynamic>?> getRootCertificate() async {
    try {
      final result = await _methodChannel.invokeMethod<Map>('getRootCertificate');
      return result != null ? Map<String, dynamic>.from(result) : null;
    } on PlatformException catch (e) {
      _errorController.add('Failed to get certificate: ${e.message}');
      return null;
    }
  }

  /// Export root CA certificate (for user to install)
  Future<Uint8List?> exportRootCertificate({String format = 'der'}) async {
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

  /// Open system certificate installer
  Future<bool> openCertificateInstaller() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('openCertificateInstaller');
      return result ?? false;
    } on PlatformException catch (e) {
      _errorController.add('Failed to open certificate installer: ${e.message}');
      return false;
    }
  }

  /// Check if root CA is installed in user trust store
  Future<bool> isRootCertificateInstalled() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('isRootCertificateInstalled');
      return result ?? false;
    } on PlatformException catch (e) {
      _errorController.add('Failed to check certificate: ${e.message}');
      return false;
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

  /// Get list of installed apps (for bypass selection)
  Future<List<Map<String, dynamic>>> getInstalledApps() async {
    try {
      final result = await _methodChannel.invokeMethod<List>('getInstalledApps');
      return result?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
    } on PlatformException catch (e) {
      _errorController.add('Failed to get apps: ${e.message}');
      return [];
    }
  }

  /// Set apps to bypass proxy
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
