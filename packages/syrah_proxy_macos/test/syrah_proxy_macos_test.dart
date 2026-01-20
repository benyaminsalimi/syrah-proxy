import 'package:flutter_test/flutter_test.dart';
import 'package:syrah_proxy_macos/syrah_proxy_macos.dart';

void main() {
  test('SyrahProxyMacOS singleton instance', () {
    final instance1 = SyrahProxyMacOS.instance;
    final instance2 = SyrahProxyMacOS.instance;
    expect(instance1, same(instance2));
  });
}
