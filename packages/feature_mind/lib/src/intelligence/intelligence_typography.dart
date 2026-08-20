import 'package:flutter/material.dart';

import '../widgets/mind_palette.dart';

/// Intelligence type roles. Technical face is AiroRulesExpanded; body stays
/// on the theme sans so long copy stays readable.
abstract final class IntelligenceTypography {
  static const String technicalFamily = 'AiroRulesExpanded';

  static TextStyle kicker([Color? color]) => TextStyle(
    fontFamily: technicalFamily,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 2.2,
    height: 1.2,
    color: color ?? MindPalette.local,
  );

  static TextStyle pageTitle(ThemeData theme) =>
      (theme.textTheme.headlineMedium ?? const TextStyle()).copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        height: 1.2,
        fontFamily: null,
      );

  static TextStyle sectionTitle(ThemeData theme) =>
      (theme.textTheme.titleLarge ?? const TextStyle()).copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        fontFamily: null,
      );

  static TextStyle cardTitle(ThemeData theme) =>
      (theme.textTheme.titleMedium ?? const TextStyle()).copyWith(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        fontFamily: null,
      );

  static TextStyle body(ThemeData theme) =>
      (theme.textTheme.bodyMedium ?? const TextStyle()).copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        fontFamily: null,
      );

  static TextStyle secondary(ThemeData theme) =>
      (theme.textTheme.bodySmall ?? const TextStyle()).copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        fontFamily: null,
      );

  static TextStyle metadata([Color? color]) => TextStyle(
    fontFamily: technicalFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.6,
    height: 1.3,
    color: color ?? MindPalette.ink.withValues(alpha: 0.72),
  );

  static TextStyle status([Color? color]) => TextStyle(
    fontFamily: technicalFamily,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.1,
    color: color ?? MindPalette.local,
  );
}
