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

          return _AppLifecycleWrapper(child: const SyrahApp());
        },
      ),
    ),
  );
}

/// Wrapper widget that handles app lifecycle events
class _AppLifecycleWrapper extends ConsumerStatefulWidget {
  final Widget child;

  const _AppLifecycleWrapper({required this.child});

  @override
  ConsumerState<_AppLifecycleWrapper> createState() => _AppLifecycleWrapperState();
}

class _AppLifecycleWrapperState extends ConsumerState<_AppLifecycleWrapper> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print('[AppLifecycle] State changed to: $state');
    if (state == AppLifecycleState.detached) {
      // App is being terminated - cleanup system proxy
      _performCleanup();
    }
  }

  Future<void> _performCleanup() async {
    print('[AppLifecycle] Performing cleanup...');
    final controller = ref.read(homeControllerProvider.notifier);
    await controller.cleanup();
    print('[AppLifecycle] Cleanup complete');
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
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
  tray.onQuitApp = () async {
    await controller.cleanup();
    SystemNavigator.pop();
  };
}
