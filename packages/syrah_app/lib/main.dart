import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'features/home/home_controller.dart';
import 'services/tray_service.dart';

void main() async {
  print('[Main] Starting SyrahProxy...');
  WidgetsFlutterBinding.ensureInitialized();
  print('[Main] Flutter binding initialized');

  // Initialize tray service on macOS
  if (Platform.isMacOS) {
    await TrayService.instance.init();
  }

  runApp(
    ProviderScope(
      child: Consumer(
        builder: (context, ref, child) {
          // Force provider initialization by reading it
          final state = ref.watch(homeControllerProvider);
          print('[Main] HomeController state: initialized=${state.isInitialized}, running=${state.isProxyRunning}');

          // Update tray icon based on proxy state (macOS only)
          if (Platform.isMacOS) {
            _setupTrayCallbacks(ref);
            TrayService.instance.setProxyRunning(state.isProxyRunning);
            TrayService.instance.setSystemProxyEnabled(state.isSystemProxyEnabled);
          }

          return const SyrahApp();
        },
      ),
    ),
  );
}

void _setupTrayCallbacks(WidgetRef ref) {
  final tray = TrayService.instance;
  final controller = ref.read(homeControllerProvider.notifier);

  tray.onStartProxy = () => controller.startProxy();
  tray.onStopProxy = () => controller.stopProxy();
  tray.onToggleSystemProxy = () => controller.toggleSystemProxy();
  tray.onShowApp = () {
    // Bring app to front
    // This would require platform-specific code
  };
  tray.onQuitApp = () => SystemNavigator.pop();
}
