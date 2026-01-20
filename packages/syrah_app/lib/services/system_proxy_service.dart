import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

/// Service to manage macOS system proxy settings
class SystemProxyService {
  static const _channel = MethodChannel('com.syrah.app/system_proxy');

  static SystemProxyService? _instance;
  static SystemProxyService get instance => _instance ??= SystemProxyService._();

  SystemProxyService._();

  bool _isEnabled = false;
  String? _activeInterface;
  String? _originalHttpProxy;
  String? _originalHttpsProxy;
  int? _originalHttpPort;
  int? _originalHttpsPort;
  bool _originalHttpEnabled = false;
  bool _originalHttpsEnabled = false;

  bool get isEnabled => _isEnabled;
  String? get activeInterface => _activeInterface;

  /// Get the active network interface (Wi-Fi or Ethernet)
  Future<String?> getActiveNetworkInterface() async {
    if (!Platform.isMacOS) return null;

    try {
      // Get list of network services
      final result = await Process.run('networksetup', ['-listallnetworkservices']);
      if (result.exitCode != 0) return null;

      final services = (result.stdout as String)
          .split('\n')
          .where((line) => line.isNotEmpty && !line.startsWith('*'))
          .toList();

      // Check which service is active (has an IP)
      for (final service in services) {
        final trimmed = service.trim();
        if (trimmed.isEmpty) continue;

        // Check if this interface has an IP address
        final ipResult = await Process.run('networksetup', ['-getinfo', trimmed]);
        if (ipResult.exitCode == 0) {
          final output = ipResult.stdout as String;
          if (output.contains('IP address:') && !output.contains('IP address: none')) {
            return trimmed;
          }
        }
      }

      // Fallback to Wi-Fi if available
      if (services.any((s) => s.contains('Wi-Fi'))) {
        return 'Wi-Fi';
      }

      return services.isNotEmpty ? services.first : null;
    } catch (e) {
      print('[SystemProxyService] Error getting network interface: $e');
      return null;
    }
  }

  /// Save current proxy settings before modifying
  Future<void> _saveOriginalSettings(String interface) async {
    try {
      // Get current HTTP proxy settings
      final httpResult = await Process.run('networksetup', ['-getwebproxy', interface]);
      if (httpResult.exitCode == 0) {
        final output = httpResult.stdout as String;
        _originalHttpEnabled = output.contains('Enabled: Yes');

        final serverMatch = RegExp(r'Server:\s*(\S+)').firstMatch(output);
        final portMatch = RegExp(r'Port:\s*(\d+)').firstMatch(output);

        _originalHttpProxy = serverMatch?.group(1);
        _originalHttpPort = portMatch != null ? int.tryParse(portMatch.group(1)!) : null;
      }

      // Get current HTTPS proxy settings
      final httpsResult = await Process.run('networksetup', ['-getsecurewebproxy', interface]);
      if (httpsResult.exitCode == 0) {
        final output = httpsResult.stdout as String;
        _originalHttpsEnabled = output.contains('Enabled: Yes');

        final serverMatch = RegExp(r'Server:\s*(\S+)').firstMatch(output);
        final portMatch = RegExp(r'Port:\s*(\d+)').firstMatch(output);

        _originalHttpsProxy = serverMatch?.group(1);
        _originalHttpsPort = portMatch != null ? int.tryParse(portMatch.group(1)!) : null;
      }

      print('[SystemProxyService] Saved original settings:');
      print('  HTTP: $_originalHttpProxy:$_originalHttpPort (enabled: $_originalHttpEnabled)');
      print('  HTTPS: $_originalHttpsProxy:$_originalHttpsPort (enabled: $_originalHttpsEnabled)');
    } catch (e) {
      print('[SystemProxyService] Error saving original settings: $e');
    }
  }

  /// Enable system proxy to route through our mitmproxy
  Future<bool> enableSystemProxy({
    String host = '127.0.0.1',
    int port = 8888,
  }) async {
    if (!Platform.isMacOS) {
      print('[SystemProxyService] System proxy only supported on macOS');
      return false;
    }

    try {
      // Get active network interface
      final interface = await getActiveNetworkInterface();
      if (interface == null) {
        print('[SystemProxyService] No active network interface found');
        return false;
      }

      print('[SystemProxyService] Configuring proxy on interface: $interface');

      // Save original settings
      await _saveOriginalSettings(interface);
      _activeInterface = interface;

      // Set HTTP proxy
      var result = await Process.run('networksetup', [
        '-setwebproxy', interface, host, port.toString()
      ]);
      if (result.exitCode != 0) {
        print('[SystemProxyService] Failed to set HTTP proxy: ${result.stderr}');
        return false;
      }

      // Enable HTTP proxy
      result = await Process.run('networksetup', [
        '-setwebproxystate', interface, 'on'
      ]);
      if (result.exitCode != 0) {
        print('[SystemProxyService] Failed to enable HTTP proxy: ${result.stderr}');
        return false;
      }

      // Set HTTPS proxy
      result = await Process.run('networksetup', [
        '-setsecurewebproxy', interface, host, port.toString()
      ]);
      if (result.exitCode != 0) {
        print('[SystemProxyService] Failed to set HTTPS proxy: ${result.stderr}');
        return false;
      }

      // Enable HTTPS proxy
      result = await Process.run('networksetup', [
        '-setsecurewebproxystate', interface, 'on'
      ]);
      if (result.exitCode != 0) {
        print('[SystemProxyService] Failed to enable HTTPS proxy: ${result.stderr}');
        return false;
      }

      _isEnabled = true;
      print('[SystemProxyService] System proxy enabled: $host:$port on $interface');
      return true;
    } catch (e) {
      print('[SystemProxyService] Error enabling system proxy: $e');
      return false;
    }
  }

  /// Disable system proxy and restore original settings
  Future<bool> disableSystemProxy() async {
    if (!Platform.isMacOS) return false;
    if (!_isEnabled || _activeInterface == null) return true;

    try {
      final interface = _activeInterface!;

      // Restore original HTTP proxy settings
      if (_originalHttpEnabled && _originalHttpProxy != null && _originalHttpPort != null) {
        await Process.run('networksetup', [
          '-setwebproxy', interface, _originalHttpProxy!, _originalHttpPort.toString()
        ]);
        await Process.run('networksetup', ['-setwebproxystate', interface, 'on']);
      } else {
        // Disable HTTP proxy
        await Process.run('networksetup', ['-setwebproxystate', interface, 'off']);
      }

      // Restore original HTTPS proxy settings
      if (_originalHttpsEnabled && _originalHttpsProxy != null && _originalHttpsPort != null) {
        await Process.run('networksetup', [
          '-setsecurewebproxy', interface, _originalHttpsProxy!, _originalHttpsPort.toString()
        ]);
        await Process.run('networksetup', ['-setsecurewebproxystate', interface, 'on']);
      } else {
        // Disable HTTPS proxy
        await Process.run('networksetup', ['-setsecurewebproxystate', interface, 'off']);
      }

      _isEnabled = false;
      print('[SystemProxyService] System proxy disabled, original settings restored');
      return true;
    } catch (e) {
      print('[SystemProxyService] Error disabling system proxy: $e');
      return false;
    }
  }

  /// Get current proxy status for display
  Future<Map<String, dynamic>> getProxyStatus() async {
    if (!Platform.isMacOS) {
      return {'supported': false};
    }

    final interface = await getActiveNetworkInterface();
    if (interface == null) {
      return {
        'supported': true,
        'interface': null,
        'enabled': false,
      };
    }

    try {
      final httpResult = await Process.run('networksetup', ['-getwebproxy', interface]);
      final httpsResult = await Process.run('networksetup', ['-getsecurewebproxy', interface]);

      final httpOutput = httpResult.stdout as String;
      final httpsOutput = httpsResult.stdout as String;

      final httpEnabled = httpOutput.contains('Enabled: Yes');
      final httpsEnabled = httpsOutput.contains('Enabled: Yes');

      String? httpServer, httpsServer;
      int? httpPort, httpsPort;

      if (httpEnabled) {
        final serverMatch = RegExp(r'Server:\s*(\S+)').firstMatch(httpOutput);
        final portMatch = RegExp(r'Port:\s*(\d+)').firstMatch(httpOutput);
        httpServer = serverMatch?.group(1);
        httpPort = portMatch != null ? int.tryParse(portMatch.group(1)!) : null;
      }

      if (httpsEnabled) {
        final serverMatch = RegExp(r'Server:\s*(\S+)').firstMatch(httpsOutput);
        final portMatch = RegExp(r'Port:\s*(\d+)').firstMatch(httpsOutput);
        httpsServer = serverMatch?.group(1);
        httpsPort = portMatch != null ? int.tryParse(portMatch.group(1)!) : null;
      }

      return {
        'supported': true,
        'interface': interface,
        'httpEnabled': httpEnabled,
        'httpsEnabled': httpsEnabled,
        'httpServer': httpServer,
        'httpPort': httpPort,
        'httpsServer': httpsServer,
        'httpsPort': httpsPort,
        'isOurProxy': httpEnabled && httpServer == '127.0.0.1' && httpPort == 8888,
      };
    } catch (e) {
      return {
        'supported': true,
        'interface': interface,
        'error': e.toString(),
      };
    }
  }
}
