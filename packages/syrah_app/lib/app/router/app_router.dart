import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/responsive/breakpoints.dart';
import '../../features/shell/mobile_shell.dart';
import '../../features/home/home_screen.dart';
import '../../features/detail/detail_screen.dart';
import '../../features/rules/rules_screen.dart';
import '../../features/breakpoint/breakpoint_screen.dart';
import '../../features/settings/settings_screen_new.dart';
import '../../features/composer/request_composer.dart';

/// Navigation shell branch keys
final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

/// Route names
class AppRoutes {
  static const home = '/';
  static const detail = '/detail/:flowId';
  static const rules = '/rules';
  static const breakpoints = '/breakpoints';
  static const settings = '/settings';
  static const composer = '/composer';

  /// Generate detail route with flow ID
  static String detailPath(String flowId) => '/detail/$flowId';
}

/// App router provider
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.home,
    debugLogDiagnostics: true,
    routes: [
      // Mobile shell with bottom navigation
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          // Only show mobile shell on mobile devices
          final isMobile = context.isMobile;
          if (isMobile) {
            return MobileShell(navigationShell: navigationShell);
          }
          // On desktop/tablet, use the current child directly
          return navigationShell;
        },
        branches: [
          // Requests branch (home)
          StatefulShellBranch(
            navigatorKey: _shellNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoutes.home,
                pageBuilder: (context, state) => NoTransitionPage(
                  key: state.pageKey,
                  child: const HomeScreen(),
                ),
                routes: [
                  // Detail screen as child of home (for push navigation)
                  GoRoute(
                    path: 'detail/:flowId',
                    parentNavigatorKey: _rootNavigatorKey,
                    pageBuilder: (context, state) {
                      final flowId = state.pathParameters['flowId'] ?? '';
                      return MaterialPage(
                        key: state.pageKey,
                        child: DetailScreen(flowId: flowId),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          // Rules branch
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.rules,
                pageBuilder: (context, state) => NoTransitionPage(
                  key: state.pageKey,
                  child: const RulesScreen(),
                ),
              ),
            ],
          ),
          // Breakpoints branch
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.breakpoints,
                pageBuilder: (context, state) => NoTransitionPage(
                  key: state.pageKey,
                  child: const BreakpointScreen(),
                ),
              ),
            ],
          ),
          // Settings branch
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.settings,
                pageBuilder: (context, state) => NoTransitionPage(
                  key: state.pageKey,
                  child: const SettingsScreen(),
                ),
              ),
            ],
          ),
        ],
      ),
      // Composer route (full screen overlay)
      GoRoute(
        path: AppRoutes.composer,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          return MaterialPage(
            key: state.pageKey,
            fullscreenDialog: true,
            child: const RequestComposer(),
          );
        },
      ),
    ],
    errorPageBuilder: (context, state) => MaterialPage(
      key: state.pageKey,
      child: Scaffold(
        body: Center(
          child: Text('Page not found: ${state.uri}'),
        ),
      ),
    ),
  );
});
