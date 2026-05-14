import 'package:flutter/material.dart';

/// Airo-specific design tokens that are not covered by Material's ColorScheme.
@immutable
class AiroThemeTokens extends ThemeExtension<AiroThemeTokens> {
  const AiroThemeTokens({
    required this.gridLine,
    required this.chromeSurface,
    required this.glow,
    required this.success,
    required this.warning,
  });

  final Color gridLine;
  final Color chromeSurface;
  final Color glow;
  final Color success;
  final Color warning;

  @override
  AiroThemeTokens copyWith({
    Color? gridLine,
    Color? chromeSurface,
    Color? glow,
    Color? success,
    Color? warning,
  }) {
    return AiroThemeTokens(
      gridLine: gridLine ?? this.gridLine,
      chromeSurface: chromeSurface ?? this.chromeSurface,
      glow: glow ?? this.glow,
      success: success ?? this.success,
      warning: warning ?? this.warning,
    );
  }

  @override
  AiroThemeTokens lerp(ThemeExtension<AiroThemeTokens>? other, double t) {
    if (other is! AiroThemeTokens) {
      return this;
    }

    return AiroThemeTokens(
      gridLine: Color.lerp(gridLine, other.gridLine, t)!,
      chromeSurface: Color.lerp(chromeSurface, other.chromeSurface, t)!,
      glow: Color.lerp(glow, other.glow, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
    );
  }
}
