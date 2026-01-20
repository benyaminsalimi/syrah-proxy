import 'package:flutter/material.dart';

import 'breakpoints.dart';

/// Adaptive layout wrapper that renders different widgets based on screen size
class ResponsiveLayout extends StatelessWidget {
  /// Widget to show on mobile screens (< 768px)
  final Widget mobile;

  /// Widget to show on tablet screens (768px - 1024px)
  /// Falls back to [mobile] if not provided
  final Widget? tablet;

  /// Widget to show on desktop screens (>= 1024px)
  /// Falls back to [tablet] or [mobile] if not provided
  final Widget? desktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        if (width >= Breakpoints.desktop && desktop != null) {
          return desktop!;
        }

        if (width >= Breakpoints.mobile && tablet != null) {
          return tablet!;
        }

        return mobile;
      },
    );
  }
}

/// Builder version of ResponsiveLayout for more control
class ResponsiveBuilder extends StatelessWidget {
  /// Builder function that receives the current device type
  final Widget Function(BuildContext context, DeviceType deviceType) builder;

  const ResponsiveBuilder({
    super.key,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        DeviceType deviceType;

        if (width >= Breakpoints.desktop) {
          deviceType = DeviceType.desktop;
        } else if (width >= Breakpoints.mobile) {
          deviceType = DeviceType.tablet;
        } else {
          deviceType = DeviceType.mobile;
        }

        return builder(context, deviceType);
      },
    );
  }
}

/// Wrapper that animates between responsive layouts
class AnimatedResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;
  final Duration duration;
  final Curve curve;

  const AnimatedResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.easeInOut,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        Widget child;

        if (width >= Breakpoints.desktop && desktop != null) {
          child = desktop!;
        } else if (width >= Breakpoints.mobile && tablet != null) {
          child = tablet!;
        } else {
          child = mobile;
        }

        return AnimatedSwitcher(
          duration: duration,
          switchInCurve: curve,
          switchOutCurve: curve,
          child: child,
        );
      },
    );
  }
}
