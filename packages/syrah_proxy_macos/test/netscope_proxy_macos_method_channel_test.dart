import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netscope_proxy_macos/netscope_proxy_macos_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelNetscopeProxyMacos platform = MethodChannelNetscopeProxyMacos();
  const MethodChannel channel = MethodChannel('netscope_proxy_macos');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        return '42';
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });
}
