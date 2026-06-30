import 'package:flutter/material.dart';
import 'responsive_center.dart';

/// Adaptive spacing utilities that scale based on screen size
class AdaptiveSpacing {
  AdaptiveSpacing._();

  // Base spacing unit (4dp)
  static const double unit = 4.0;

  /// Get scaled spacing value based on screen width
  static double getSpacing(
    BuildContext context,
    double baseSpacing, {
    double mobileScale = 0.85,
    double tabletScale = 1.0,
    double desktopScale = 1.15,
  }) {
    final width = MediaQuery.of(context).size.width;

    if (width < ResponsiveBreakpoints.mobile) {
      return baseSpacing * mobileScale;
    } else if (width >= ResponsiveBreakpoints.desktop) {
      return baseSpacing * desktopScale;
    } else {
      return baseSpacing * tabletScale;
    }
  }

  /// Adaptive spacing values
  static double xxs(BuildContext context) => getSpacing(context, 2.0);
  static double xs(BuildContext context) => getSpacing(context, 4.0);
  static double sm(BuildContext context) => getSpacing(context, 8.0);
  static double md(BuildContext context) => getSpacing(context, 16.0);
  static double lg(BuildContext context) => getSpacing(context, 24.0);
  static double xl(BuildContext context) => getSpacing(context, 32.0);
  static double xxl(BuildContext context) => getSpacing(context, 48.0);
  static double xxxl(BuildContext context) => getSpacing(context, 64.0);

  /// Adaptive padding
  static EdgeInsets paddingXs(BuildContext context) =>
      EdgeInsets.all(xs(context));
  static EdgeInsets paddingSm(BuildContext context) =>
      EdgeInsets.all(sm(context));
  static EdgeInsets paddingMd(BuildContext context) =>
      EdgeInsets.all(md(context));
  static EdgeInsets paddingLg(BuildContext context) =>
      EdgeInsets.all(lg(context));
  static EdgeInsets paddingXl(BuildContext context) =>
      EdgeInsets.all(xl(context));

  /// Adaptive horizontal padding
  static EdgeInsets paddingHorizontalXs(BuildContext context) =>
      EdgeInsets.symmetric(horizontal: xs(context));
  static EdgeInsets paddingHorizontalSm(BuildContext context) =>
      EdgeInsets.symmetric(horizontal: sm(context));
  static EdgeInsets paddingHorizontalMd(BuildContext context) =>
      EdgeInsets.symmetric(horizontal: md(context));
  static EdgeInsets paddingHorizontalLg(BuildContext context) =>
      EdgeInsets.symmetric(horizontal: lg(context));

  /// Adaptive vertical padding
  static EdgeInsets paddingVerticalXs(BuildContext context) =>
      EdgeInsets.symmetric(vertical: xs(context));
  static EdgeInsets paddingVerticalSm(BuildContext context) =>
      EdgeInsets.symmetric(vertical: sm(context));
  static EdgeInsets paddingVerticalMd(BuildContext context) =>
      EdgeInsets.symmetric(vertical: md(context));
  static EdgeInsets paddingVerticalLg(BuildContext context) =>
      EdgeInsets.symmetric(vertical: lg(context));

  /// Adaptive gap widgets
  static Widget gapXs(BuildContext context) {
    final spacing = xs(context);
    return SizedBox(width: spacing, height: spacing);
  }

  static Widget gapSm(BuildContext context) {
    final spacing = sm(context);
    return SizedBox(width: spacing, height: spacing);
  }

  static Widget gapMd(BuildContext context) {
    final spacing = md(context);
    return SizedBox(width: spacing, height: spacing);
  }

  static Widget gapLg(BuildContext context) {
    final spacing = lg(context);
    return SizedBox(width: spacing, height: spacing);
  }

  static Widget gapXl(BuildContext context) {
    final spacing = xl(context);
    return SizedBox(width: spacing, height: spacing);
  }

  /// Adaptive horizontal gaps
  static Widget gapHorizontalXs(BuildContext context) =>
      SizedBox(width: xs(context));
  static Widget gapHorizontalSm(BuildContext context) =>
      SizedBox(width: sm(context));
  static Widget gapHorizontalMd(BuildContext context) =>
      SizedBox(width: md(context));
  static Widget gapHorizontalLg(BuildContext context) =>
      SizedBox(width: lg(context));

  /// Adaptive vertical gaps
  static Widget gapVerticalXs(BuildContext context) =>
      SizedBox(height: xs(context));
  static Widget gapVerticalSm(BuildContext context) =>
      SizedBox(height: sm(context));
  static Widget gapVerticalMd(BuildContext context) =>
      SizedBox(height: md(context));
  static Widget gapVerticalLg(BuildContext context) =>
      SizedBox(height: lg(context));

  /// Adaptive border radius
  static double radiusXs(BuildContext context) => getSpacing(context, 4.0);
  static double radiusSm(BuildContext context) => getSpacing(context, 8.0);
  static double radiusMd(BuildContext context) => getSpacing(context, 12.0);
  static double radiusLg(BuildContext context) => getSpacing(context, 16.0);
  static double radiusXl(BuildContext context) => getSpacing(context, 24.0);
}
