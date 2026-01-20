import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// macOS proxy plugin for Syrah
class SyrahProxyMacOS {
  static const _methodChannel = MethodChannel('dev.syrah.proxy.macos/methods');
  static const _eventChannel = EventChannel('dev.syrah.proxy.macos/flows');
  static const _statusChannel = EventChannel('dev.syrah.proxy.macos/status');

  static SyrahProxyMacOS? _instance;

  /// Singleton instance
  static SyrahProxyMacOS get instance {
    _instance ??= SyrahProxyMacOS._();
    return _instance!;
  }

  SyrahProxyMacOS._();

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
    String bindAddress = '127.0.0.1',
    bool enableSslInterception = true,
    List<String> bypassHosts = const [],
  }) async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('startProxy', {
        'port': port,
        'bindAddress': bindAddress,
        'enableSslInterception': enableSslInterception,
        'bypassHosts': bypassHosts,
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

  /// Install root CA certificate to system keychain
  Future<bool> installRootCertificate() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('installRootCertificate');
      return result ?? false;
    } on PlatformException catch (e) {
      _errorController.add('Failed to install certificate: ${e.message}');
      return false;
    }
  }

  /// Check if root CA is trusted
  Future<bool> isRootCertificateTrusted() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('isRootCertificateTrusted');
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

  /// Configure system proxy settings
  Future<bool> configureSystemProxy({required bool enable}) async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('configureSystemProxy', {
        'enable': enable,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      _errorController.add('Failed to configure system proxy: ${e.message}');
      return false;
    }
  }

  /// Install network extension
  Future<bool> installNetworkExtension() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('installNetworkExtension');
      return result ?? false;
    } on PlatformException catch (e) {
      _errorController.add('Failed to install extension: ${e.message}');
      return false;
    }
  }

  /// Check if network extension is installed
  Future<bool> isNetworkExtensionInstalled() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('isNetworkExtensionInstalled');
      return result ?? false;
    } on PlatformException catch (e) {
      _errorController.add('Failed to check extension: ${e.message}');
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
