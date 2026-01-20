import 'package:flutter/material.dart';

/// Responsive breakpoints for different screen sizes
class Breakpoints {
  Breakpoints._();

  /// Mobile: < 768px (phones)
  static const double mobile = 768;

  /// Tablet: 768px - 1024px (tablets, small laptops)
  static const double tablet = 1024;

  /// Desktop: >= 1024px (laptops, desktops)
  static const double desktop = 1024;
}

/// Extension on BuildContext for responsive layout helpers
extension ResponsiveExtension on BuildContext {
  /// Get the current screen width
  double get screenWidth => MediaQuery.of(this).size.width;

  /// Get the current screen height
  double get screenHeight => MediaQuery.of(this).size.height;

  /// Check if current screen is mobile size
  bool get isMobile => screenWidth < Breakpoints.mobile;

  /// Check if current screen is tablet size
  bool get isTablet =>
      screenWidth >= Breakpoints.mobile && screenWidth < Breakpoints.tablet;

  /// Check if current screen is desktop size
  bool get isDesktop => screenWidth >= Breakpoints.desktop;

  /// Check if device is in portrait orientation
  bool get isPortrait => screenHeight > screenWidth;

  /// Check if device is in landscape orientation
  bool get isLandscape => screenWidth > screenHeight;

  /// Get responsive value based on screen size
  T responsive<T>({
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    if (isDesktop && desktop != null) return desktop;
    if (isTablet && tablet != null) return tablet;
    return mobile;
  }
}

/// Device type enum
enum DeviceType {
  mobile,
  tablet,
  desktop,
}

/// Get current device type based on screen width
DeviceType getDeviceType(BuildContext context) {
  final width = MediaQuery.of(context).size.width;
  if (width < Breakpoints.mobile) return DeviceType.mobile;
  if (width < Breakpoints.tablet) return DeviceType.tablet;
  return DeviceType.desktop;
}
