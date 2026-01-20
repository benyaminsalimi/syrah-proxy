import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'theme/app_theme.dart';
import 'router/app_router.dart';
import '../features/home/home_screen.dart';
import '../features/home/home_controller.dart';
import '../services/certificate_service.dart';

/// Main application widget
class SyrahApp extends ConsumerWidget {
  const SyrahApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    // Only add menu bar on macOS
    if (Platform.isMacOS) {
      return _SyrahAppWithMenuBar(router: router);
    }

    return MaterialApp.router(
      title: 'SyrahProxy',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.light,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}

/// macOS app with native menu bar
class _SyrahAppWithMenuBar extends ConsumerWidget {
  final RouterConfig<Object> router;

  const _SyrahAppWithMenuBar({required this.router});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isProxyRunning = ref.watch(proxyRunningProvider);
    final isSystemProxyEnabled = ref.watch(systemProxyEnabledProvider);
    final controller = ref.read(homeControllerProvider.notifier);

    return PlatformMenuBar(
      menus: [
        // App Menu (SyrahProxy)
        PlatformMenu(
          label: 'SyrahProxy',
          menus: [
            PlatformMenuItem(
              label: 'About SyrahProxy',
              onSelected: () => _showAboutDialog(context),
            ),
            const PlatformMenuItemGroup(members: []),
            PlatformMenuItem(
              label: 'Settings...',
              shortcut: const SingleActivator(LogicalKeyboardKey.comma, meta: true),
              onSelected: () {
                // Navigate to settings using GoRouter
              },
            ),
            const PlatformMenuItemGroup(members: []),
            PlatformMenuItem(
              label: 'Quit SyrahProxy',
              shortcut: const SingleActivator(LogicalKeyboardKey.keyQ, meta: true),
              onSelected: () => SystemNavigator.pop(),
            ),
          ],
        ),

        // Proxy Menu
        PlatformMenu(
          label: 'Proxy',
          menus: [
            PlatformMenuItem(
              label: isProxyRunning ? 'Stop Proxy' : 'Start Proxy',
              shortcut: const SingleActivator(LogicalKeyboardKey.keyR, meta: true),
              onSelected: () => controller.toggleProxy(),
            ),
            const PlatformMenuItemGroup(members: []),
            PlatformMenuItem(
              label: isSystemProxyEnabled ? 'Disable System Proxy' : 'Enable System Proxy',
              shortcut: const SingleActivator(LogicalKeyboardKey.keyS, meta: true, shift: true),
              onSelected: () => controller.toggleSystemProxy(),
            ),
            const PlatformMenuItemGroup(members: []),
            PlatformMenuItem(
              label: 'Trust Certificate...',
              onSelected: () => _showCertificateDialog(context),
            ),
          ],
        ),

        // Edit Menu
        PlatformMenu(
          label: 'Edit',
          menus: [
            PlatformMenuItem(
              label: 'Cut',
              shortcut: const SingleActivator(LogicalKeyboardKey.keyX, meta: true),
              onSelected: () {
                // Handled by Flutter's default text editing
              },
            ),
            PlatformMenuItem(
              label: 'Copy',
              shortcut: const SingleActivator(LogicalKeyboardKey.keyC, meta: true),
              onSelected: () {
                // Handled by Flutter's default text editing
              },
            ),
            PlatformMenuItem(
              label: 'Paste',
              shortcut: const SingleActivator(LogicalKeyboardKey.keyV, meta: true),
              onSelected: () {
                // Handled by Flutter's default text editing
              },
            ),
            PlatformMenuItem(
              label: 'Select All',
              shortcut: const SingleActivator(LogicalKeyboardKey.keyA, meta: true),
              onSelected: () {
                // Handled by Flutter's default text editing
              },
            ),
          ],
        ),

        // View Menu
        PlatformMenu(
          label: 'View',
          menus: [
            PlatformMenuItem(
              label: 'Clear All Flows',
              shortcut: const SingleActivator(LogicalKeyboardKey.keyK, meta: true),
              onSelected: () => controller.clearFlows(),
            ),
            const PlatformMenuItemGroup(members: []),
            PlatformMenuItem(
              label: 'Clear Pins',
              onSelected: () => controller.clearPins(),
            ),
            PlatformMenuItem(
              label: 'Clear Filters',
              shortcut: const SingleActivator(LogicalKeyboardKey.keyL, meta: true, shift: true),
              onSelected: () => controller.clearFilters(),
            ),
          ],
        ),

        // Window Menu
        PlatformMenu(
          label: 'Window',
          menus: [
            PlatformMenuItem(
              label: 'Minimize',
              shortcut: const SingleActivator(LogicalKeyboardKey.keyM, meta: true),
              onSelected: () {
                // Handled by system
              },
            ),
          ],
        ),

        // Help Menu
        PlatformMenu(
          label: 'Help',
          menus: [
            PlatformMenuItem(
              label: 'SyrahProxy Help',
              onSelected: () {
                // TODO: Open help documentation at proxy.syrah.dev
              },
            ),
          ],
        ),
      ],
      child: MaterialApp.router(
        title: 'SyrahProxy',
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.light,
        routerConfig: router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'SyrahProxy',
      applicationVersion: '1.0.0',
      applicationIcon: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset(
          'assets/icons/syrah_logo.png',
          width: 64,
          height: 64,
          errorBuilder: (context, error, stackTrace) {
            // Fallback icon if image fails to load
            return Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFF722F37), // Wine color
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.wine_bar,
                color: Colors.white,
                size: 40,
              ),
            );
          },
        ),
      ),
      applicationLegalese: '© 2026 Syrah Project\nOpen Source Network Debugging Proxy\nhttps://proxy.syrah.dev',
      children: [
        const SizedBox(height: 16),
        const Text(
          'A powerful HTTP/HTTPS debugging proxy for developers.',
          style: TextStyle(fontSize: 13),
        ),
        const SizedBox(height: 8),
        const Text(
          'https://github.com/benyaminsalimi/syrah-proxy',
          style: TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }

  void _showCertificateDialog(BuildContext context) {
    CertificateService.showInstallDialog(context);
  }
}

/// Legacy MaterialApp for desktop (non-router version)
/// Use this if you want to bypass router on desktop
class SyrahAppLegacy extends ConsumerWidget {
  const SyrahAppLegacy({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'SyrahProxy',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.light,
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
