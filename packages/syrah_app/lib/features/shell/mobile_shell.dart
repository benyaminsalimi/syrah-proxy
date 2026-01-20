import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_theme.dart';
import '../../app/router/app_router.dart';
import '../home/home_controller.dart';

/// Mobile shell with bottom navigation bar
class MobileShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const MobileShell({
    super.key,
    required this.navigationShell,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRunning = ref.watch(proxyRunningProvider);
    final enabledBreakpoints = ref.watch(enabledBreakpointsCountProvider);
    final enabledRules = ref.watch(enabledRulesCountProvider);

    return Scaffold(
      body: navigationShell,
      floatingActionButton: navigationShell.currentIndex == 0
          ? FloatingActionButton(
              onPressed: () => context.push(AppRoutes.composer),
              tooltip: 'Compose Request',
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => _onDestinationSelected(context, index),
        destinations: [
          NavigationDestination(
            icon: Badge(
              isLabelVisible: isRunning,
              backgroundColor: AppColors.success,
              child: const Icon(Icons.http_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: isRunning,
              backgroundColor: AppColors.success,
              child: const Icon(Icons.http),
            ),
            label: 'Requests',
          ),
          NavigationDestination(
            icon: Badge(
              label: enabledRules > 0 ? Text('$enabledRules') : null,
              isLabelVisible: enabledRules > 0,
              child: const Icon(Icons.rule_outlined),
            ),
            selectedIcon: Badge(
              label: enabledRules > 0 ? Text('$enabledRules') : null,
              isLabelVisible: enabledRules > 0,
              child: const Icon(Icons.rule),
            ),
            label: 'Rules',
          ),
          NavigationDestination(
            icon: Badge(
              label: enabledBreakpoints > 0 ? Text('$enabledBreakpoints') : null,
              isLabelVisible: enabledBreakpoints > 0,
              child: const Icon(Icons.pause_circle_outline),
            ),
            selectedIcon: Badge(
              label: enabledBreakpoints > 0 ? Text('$enabledBreakpoints') : null,
              isLabelVisible: enabledBreakpoints > 0,
              child: const Icon(Icons.pause_circle),
            ),
            label: 'Breakpoints',
          ),
          const NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  void _onDestinationSelected(BuildContext context, int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}

/// Provider for enabled breakpoints count
final enabledBreakpointsCountProvider = Provider<int>((ref) {
  // This should be connected to breakpoint controller
  // For now return 0, will be connected when breakpoint controller is available
  return 0;
});

/// Provider for enabled rules count
final enabledRulesCountProvider = Provider<int>((ref) {
  // This should be connected to rules controller
  // For now return 0, will be connected when rules controller is available
  return 0;
});
