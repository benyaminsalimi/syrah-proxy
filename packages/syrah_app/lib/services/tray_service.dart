import 'dart:io';

import 'package:flutter/material.dart';
import 'package:tray_manager/tray_manager.dart';

/// Service for managing macOS menu bar status icon
class TrayService with TrayListener {
  static TrayService? _instance;
  static TrayService get instance => _instance ??= TrayService._();

  TrayService._();

  bool _isInitialized = false;
  bool _isProxyRunning = false;
  bool _isSystemProxyEnabled = false;

  VoidCallback? onStartProxy;
  VoidCallback? onStopProxy;
  VoidCallback? onToggleSystemProxy;
  VoidCallback? onShowApp;
  VoidCallback? onQuitApp;

  /// Initialize the tray icon (macOS only)
  Future<void> init() async {
    if (!Platform.isMacOS || _isInitialized) return;

    _isInitialized = true;
    trayManager.addListener(this);

    await _updateTrayIcon();
    await _updateTrayMenu();
  }

  /// Update the proxy running state
  Future<void> setProxyRunning(bool running) async {
    if (_isProxyRunning == running) return;
    _isProxyRunning = running;
    await _updateTrayIcon();
    await _updateTrayMenu();
  }

  /// Update the system proxy state
  Future<void> setSystemProxyEnabled(bool enabled) async {
    if (_isSystemProxyEnabled == enabled) return;
    _isSystemProxyEnabled = enabled;
    await _updateTrayMenu();
  }

  Future<void> _updateTrayIcon() async {
    // Use different icons based on proxy state
    // For now, we'll use a text-based approach since we need to bundle icons
    final iconPath = _isProxyRunning
        ? 'assets/icons/tray_active.png'
        : 'assets/icons/tray_inactive.png';

    try {
      await trayManager.setIcon(iconPath);
    } catch (e) {
      // Fallback: try to set a basic icon
      print('Failed to set tray icon: $e');
    }

    // Set tooltip
    await trayManager.setToolTip(
      _isProxyRunning ? 'SyrahProxy - Running' : 'SyrahProxy - Stopped',
    );
  }

  Future<void> _updateTrayMenu() async {
    final menu = Menu(
      items: [
        MenuItem(
          label: 'SyrahProxy',
          disabled: true,
        ),
        MenuItem.separator(),
        MenuItem(
          label: _isProxyRunning ? 'Stop Proxy' : 'Start Proxy',
          key: 'toggle_proxy',
        ),
        MenuItem.separator(),
        MenuItem(
          label: _isSystemProxyEnabled ? 'Disable System Proxy' : 'Enable System Proxy',
          key: 'toggle_system_proxy',
          disabled: !_isProxyRunning,
        ),
        MenuItem.separator(),
        MenuItem(
          label: 'Show SyrahProxy',
          key: 'show_app',
        ),
        MenuItem.separator(),
        MenuItem(
          label: 'Quit',
          key: 'quit',
        ),
      ],
    );

    await trayManager.setContextMenu(menu);
  }

  @override
  void onTrayIconMouseDown() {
    // Show menu on click
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'toggle_proxy':
        if (_isProxyRunning) {
          onStopProxy?.call();
        } else {
          onStartProxy?.call();
        }
        break;
      case 'toggle_system_proxy':
        onToggleSystemProxy?.call();
        break;
      case 'show_app':
        onShowApp?.call();
        break;
      case 'quit':
        onQuitApp?.call();
        break;
    }
  }

  /// Dispose of resources
  Future<void> dispose() async {
    if (!_isInitialized) return;
    trayManager.removeListener(this);
    await trayManager.destroy();
    _isInitialized = false;
  }
}
