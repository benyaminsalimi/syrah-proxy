import 'package:flutter_test/flutter_test.dart';
import 'package:netscope_proxy_android/netscope_proxy_android.dart';
import 'package:netscope_proxy_android/netscope_proxy_android_platform_interface.dart';
import 'package:netscope_proxy_android/netscope_proxy_android_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockNetscopeProxyAndroidPlatform
    with MockPlatformInterfaceMixin
    implements NetscopeProxyAndroidPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final NetscopeProxyAndroidPlatform initialPlatform = NetscopeProxyAndroidPlatform.instance;

  test('$MethodChannelNetscopeProxyAndroid is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelNetscopeProxyAndroid>());
  });

  test('getPlatformVersion', () async {
    NetscopeProxyAndroid netscopeProxyAndroidPlugin = NetscopeProxyAndroid();
    MockNetscopeProxyAndroidPlatform fakePlatform = MockNetscopeProxyAndroidPlatform();
    NetscopeProxyAndroidPlatform.instance = fakePlatform;

    expect(await netscopeProxyAndroidPlugin.getPlatformVersion(), '42');
  });
}
