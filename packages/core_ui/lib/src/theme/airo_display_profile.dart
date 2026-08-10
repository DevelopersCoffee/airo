import 'package:flutter/widgets.dart';

/// The display environment a widget tree is being rendered into.
///
/// Semantic typography/spacing levels (see [AiroTypography]) resolve their
/// physical size through this profile instead of every call site hardcoding
/// a pixel value per device. `accessible`/`highContrast` are signal-driven
/// (OS text scale / contrast setting) and win over the size-based profiles
/// regardless of screen size — a phone with a large system text scale still
/// gets accessible-sized type.
enum AiroDisplayProfile {
  compact,
  standard,
  tablet,
  tv,
  largeDisplay,
  accessible,
  highContrast;

  /// Resolve the profile for the current [context].
  ///
  /// Order of evaluation: OS accessibility signals first (they must win
  /// regardless of physical size), then physical size/shortest-side
  /// thresholds derived from Material's standard breakpoints extended with
  /// TV-scale bands.
  ///
  /// Reference physical px for `AiroTypography.displayLarge` per profile,
  /// used to size-check the resolver in tests:
  /// compact=32, tablet=42, tv=56, largeDisplay=64.
  static AiroDisplayProfile resolve(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    if (mediaQuery.highContrast) {
      return AiroDisplayProfile.highContrast;
    }
    if (mediaQuery.textScaler.scale(1.0) >= _accessibleTextScaleThreshold) {
      return AiroDisplayProfile.accessible;
    }

    final shortestSide = mediaQuery.size.shortestSide;
    final longestSide = mediaQuery.size.longestSide;

    if (longestSide >= _largeDisplayLongestSideThreshold) {
      return AiroDisplayProfile.largeDisplay;
    }
    if (shortestSide >= _tvShortestSideThreshold) {
      return AiroDisplayProfile.tv;
    }
    if (shortestSide >= _tabletShortestSideThreshold) {
      return AiroDisplayProfile.tablet;
    }
    if (shortestSide >= _standardShortestSideThreshold) {
      return AiroDisplayProfile.standard;
    }
    return AiroDisplayProfile.compact;
  }

  static const double _accessibleTextScaleThreshold = 1.3;
  static const double _standardShortestSideThreshold = 500;
  static const double _tabletShortestSideThreshold = 600;
  static const double _tvShortestSideThreshold = 900;
  static const double _largeDisplayLongestSideThreshold = 3000;
}
