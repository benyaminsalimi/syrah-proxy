import 'package:flutter_test/flutter_test.dart';
import 'package:netscope_proxy_macos/netscope_proxy_macos.dart';
import 'package:netscope_proxy_macos/netscope_proxy_macos_platform_interface.dart';
import 'package:netscope_proxy_macos/netscope_proxy_macos_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockNetscopeProxyMacosPlatform
    with MockPlatformInterfaceMixin
    implements NetscopeProxyMacosPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final NetscopeProxyMacosPlatform initialPlatform = NetscopeProxyMacosPlatform.instance;

  test('$MethodChannelNetscopeProxyMacos is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelNetscopeProxyMacos>());
  });

  test('getPlatformVersion', () async {
    NetscopeProxyMacos netscopeProxyMacosPlugin = NetscopeProxyMacos();
    MockNetscopeProxyMacosPlatform fakePlatform = MockNetscopeProxyMacosPlatform();
    NetscopeProxyMacosPlatform.instance = fakePlatform;

    expect(await netscopeProxyMacosPlugin.getPlatformVersion(), '42');
  });
}
