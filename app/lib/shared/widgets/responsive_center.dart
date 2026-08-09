import 'package:flutter/material.dart';

/// Responsive wrapper that constrains content width on large screens
/// while maintaining full width on mobile devices.
///
/// This prevents UI elements from stretching infinitely on desktop/web
/// and provides optimal reading/interaction widths.
class ResponsiveCenter extends StatelessWidget {
  const ResponsiveCenter({
    super.key,
    required this.child,
    this.maxWidth = ResponsiveBreakpoints.contentMaxWidth,
    this.padding,
  });

  /// The widget to constrain
  final Widget child;

  /// Maximum width for the content (default: 1000px for standard screens)
  final double maxWidth;

  /// Optional padding around the content
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    Widget content = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    );

    if (padding != null) {
      content = Padding(padding: padding!, child: content);
    }

    return Center(child: content);
  }
}

/// Standard responsive breakpoints and max-width values
class ResponsiveBreakpoints {
  ResponsiveBreakpoints._();

  // Breakpoints (screen width thresholds)
  static const double mobile = 600;
  static const double tablet = 1024;
  static const double desktop = 1440;

  // Max content widths by content type
  static const double formMaxWidth = 400; // Auth forms, narrow inputs
  static const double textMaxWidth = 800; // Text-heavy content, articles
  static const double contentMaxWidth = 1000; // Standard app screens
  static const double dashboardMaxWidth = 1200; // Wide dashboards, grids
  static const double wideMaxWidth = 1440; // Maximum for ultra-wide monitors

  /// Get the appropriate column count for a grid based on screen width
  static int getGridColumns(
    double width, {
    int mobile = 2,
    int tablet = 3,
    int desktop = 4,
  }) {
    if (width < ResponsiveBreakpoints.mobile) {
      return mobile;
    } else if (width < ResponsiveBreakpoints.tablet) {
      return tablet;
    } else {
      return desktop;
    }
  }

  /// Check if the current screen is mobile-sized
  static bool isMobile(BuildContext context) {
    return MediaQuery.sizeOf(context).width < mobile;
  }

  /// Check if the current screen is tablet-sized
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= mobile && width < tablet;
  }

  /// Check if the current screen is desktop-sized
  static bool isDesktop(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= tablet;
  }

  /// Get responsive horizontal padding (5% of screen width, clamped)
  static EdgeInsets getResponsivePadding(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final horizontalPadding = (width * 0.05).clamp(16.0, 48.0);
    return EdgeInsets.symmetric(horizontal: horizontalPadding);
  }

  /// Check if current screen is wide desktop
  static bool isWideDesktop(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= desktop;
  }

  /// Get current breakpoint name
  static String getBreakpointName(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < mobile) return 'mobile';
    if (width < tablet) return 'tablet';
    if (width < desktop) return 'desktop';
    return 'wide-desktop';
  }

  /// Get value based on current breakpoint
  static T getValue<T>(
    BuildContext context, {
    required T mobile,
    T? tablet,
    T? desktop,
    T? wideDesktop,
  }) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= ResponsiveBreakpoints.desktop && wideDesktop != null) {
      return wideDesktop;
    }
    if (width >= ResponsiveBreakpoints.tablet && desktop != null) {
      return desktop;
    }
    if (width >= ResponsiveBreakpoints.mobile && tablet != null) {
      return tablet;
    }
    return mobile;
  }
}

/// Adaptive layout builder that switches between mobile, tablet, and desktop layouts
class AdaptiveLayout extends StatelessWidget {
  const AdaptiveLayout({
    super.key,
    required this.mobileLayout,
    this.tabletLayout,
    required this.desktopLayout,
  });

  /// Layout for mobile screens (< 600px)
  final Widget mobileLayout;

  /// Layout for tablet screens (600-1024px). Falls back to mobile if not provided.
  final Widget? tabletLayout;

  /// Layout for desktop screens (>= 1024px)
  final Widget desktopLayout;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < ResponsiveBreakpoints.mobile) {
          return mobileLayout;
        } else if (constraints.maxWidth < ResponsiveBreakpoints.tablet) {
          return tabletLayout ?? mobileLayout;
        } else {
          return desktopLayout;
        }
      },
    );
  }
}

/// Responsive grid that automatically adjusts column count based on screen width
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    super.key,
    required this.children,
    this.mobileColumns = 2,
    this.tabletColumns = 3,
    this.desktopColumns = 4,
    this.crossAxisSpacing = 12,
    this.mainAxisSpacing = 12,
    this.childAspectRatio = 1.0,
    this.padding,
  });

  final List<Widget> children;
  final int mobileColumns;
  final int tabletColumns;
  final int desktopColumns;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final double childAspectRatio;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = ResponsiveBreakpoints.getGridColumns(
          constraints.maxWidth,
          mobile: mobileColumns,
          tablet: tabletColumns,
          desktop: desktopColumns,
        );

        return GridView.count(
          crossAxisCount: columns,
          crossAxisSpacing: crossAxisSpacing,
          mainAxisSpacing: mainAxisSpacing,
          childAspectRatio: childAspectRatio,
          padding: padding,
          children: children,
        );
      },
    );
  }
}
