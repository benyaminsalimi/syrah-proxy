import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'netscope_proxy_android_method_channel.dart';

abstract class NetscopeProxyAndroidPlatform extends PlatformInterface {
  /// Constructs a NetscopeProxyAndroidPlatform.
  NetscopeProxyAndroidPlatform() : super(token: _token);

  static final Object _token = Object();

  static NetscopeProxyAndroidPlatform _instance = MethodChannelNetscopeProxyAndroid();

  /// The default instance of [NetscopeProxyAndroidPlatform] to use.
  ///
  /// Defaults to [MethodChannelNetscopeProxyAndroid].
  static NetscopeProxyAndroidPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [NetscopeProxyAndroidPlatform] when
  /// they register themselves.
  static set instance(NetscopeProxyAndroidPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
