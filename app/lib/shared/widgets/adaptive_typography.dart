import 'package:flutter/material.dart';
import 'responsive_center.dart';

/// Adaptive typography that scales text based on screen size
class AdaptiveText extends StatelessWidget {
  const AdaptiveText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.overflow,
    this.maxLines,
    this.scaleFactor = 1.0,
  });

  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final TextOverflow? overflow;
  final int? maxLines;
  final double scaleFactor;

  @override
  Widget build(BuildContext context) {
    final baseStyle = style ?? Theme.of(context).textTheme.bodyMedium;
    final adaptiveStyle = _getAdaptiveTextStyle(context, baseStyle!);

    return Text(
      text,
      style: adaptiveStyle,
      textAlign: textAlign,
      overflow: overflow,
      maxLines: maxLines,
    );
  }

  TextStyle _getAdaptiveTextStyle(BuildContext context, TextStyle baseStyle) {
    final width = MediaQuery.of(context).size.width;
    double scale = scaleFactor;

    // Scale text based on screen width
    if (width < ResponsiveBreakpoints.mobile) {
      // Mobile: Slightly smaller
      scale *= 0.95;
    } else if (width >= ResponsiveBreakpoints.desktop) {
      // Desktop: Slightly larger
      scale *= 1.05;
    }
    // Tablet: Keep base size (scale *= 1.0)

    return baseStyle.copyWith(fontSize: (baseStyle.fontSize ?? 14) * scale);
  }
}

/// Adaptive typography utilities for responsive text scaling
class AdaptiveTypography {
  AdaptiveTypography._();

  /// Get scaled font size based on screen width
  static double getScaledFontSize(
    BuildContext context,
    double baseFontSize, {
    double mobileScale = 0.95,
    double tabletScale = 1.0,
    double desktopScale = 1.05,
  }) {
    final width = MediaQuery.of(context).size.width;

    if (width < ResponsiveBreakpoints.mobile) {
      return baseFontSize * mobileScale;
    } else if (width >= ResponsiveBreakpoints.desktop) {
      return baseFontSize * desktopScale;
    } else {
      return baseFontSize * tabletScale;
    }
  }

  /// Get adaptive text theme based on screen size
  static TextTheme getAdaptiveTextTheme(BuildContext context) {
    final baseTheme = Theme.of(context).textTheme;
    final width = MediaQuery.of(context).size.width;

    double scale = 1.0;
    if (width < ResponsiveBreakpoints.mobile) {
      scale = 0.95;
    } else if (width >= ResponsiveBreakpoints.desktop) {
      scale = 1.05;
    }

    return TextTheme(
      displayLarge: baseTheme.displayLarge?.copyWith(
        fontSize: (baseTheme.displayLarge?.fontSize ?? 57) * scale,
      ),
      displayMedium: baseTheme.displayMedium?.copyWith(
        fontSize: (baseTheme.displayMedium?.fontSize ?? 45) * scale,
      ),
      displaySmall: baseTheme.displaySmall?.copyWith(
        fontSize: (baseTheme.displaySmall?.fontSize ?? 36) * scale,
      ),
      headlineLarge: baseTheme.headlineLarge?.copyWith(
        fontSize: (baseTheme.headlineLarge?.fontSize ?? 32) * scale,
      ),
      headlineMedium: baseTheme.headlineMedium?.copyWith(
        fontSize: (baseTheme.headlineMedium?.fontSize ?? 28) * scale,
      ),
      headlineSmall: baseTheme.headlineSmall?.copyWith(
        fontSize: (baseTheme.headlineSmall?.fontSize ?? 24) * scale,
      ),
      titleLarge: baseTheme.titleLarge?.copyWith(
        fontSize: (baseTheme.titleLarge?.fontSize ?? 22) * scale,
      ),
      titleMedium: baseTheme.titleMedium?.copyWith(
        fontSize: (baseTheme.titleMedium?.fontSize ?? 16) * scale,
      ),
      titleSmall: baseTheme.titleSmall?.copyWith(
        fontSize: (baseTheme.titleSmall?.fontSize ?? 14) * scale,
      ),
      bodyLarge: baseTheme.bodyLarge?.copyWith(
        fontSize: (baseTheme.bodyLarge?.fontSize ?? 16) * scale,
      ),
      bodyMedium: baseTheme.bodyMedium?.copyWith(
        fontSize: (baseTheme.bodyMedium?.fontSize ?? 14) * scale,
      ),
      bodySmall: baseTheme.bodySmall?.copyWith(
        fontSize: (baseTheme.bodySmall?.fontSize ?? 12) * scale,
      ),
      labelLarge: baseTheme.labelLarge?.copyWith(
        fontSize: (baseTheme.labelLarge?.fontSize ?? 14) * scale,
      ),
      labelMedium: baseTheme.labelMedium?.copyWith(
        fontSize: (baseTheme.labelMedium?.fontSize ?? 12) * scale,
      ),
      labelSmall: baseTheme.labelSmall?.copyWith(
        fontSize: (baseTheme.labelSmall?.fontSize ?? 11) * scale,
      ),
    );
  }
}
