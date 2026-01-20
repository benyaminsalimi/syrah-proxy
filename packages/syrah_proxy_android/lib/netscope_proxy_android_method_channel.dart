import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'netscope_proxy_android_platform_interface.dart';

/// An implementation of [NetscopeProxyAndroidPlatform] that uses method channels.
class MethodChannelNetscopeProxyAndroid extends NetscopeProxyAndroidPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('netscope_proxy_android');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
