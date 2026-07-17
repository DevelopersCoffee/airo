import 'package:flutter/material.dart';

/// Application color palette
abstract final class AppColors {
  // Primary colors
  static const Color primary = Color(0xFF6750A4);
  static const Color primaryContainer = Color(0xFFEADDFF);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onPrimaryContainer = Color(0xFF21005D);

  // Secondary colors
  static const Color secondary = Color(0xFF625B71);
  static const Color secondaryContainer = Color(0xFFE8DEF8);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color onSecondaryContainer = Color(0xFF1D192B);

  // Tertiary colors
  static const Color tertiary = Color(0xFF7D5260);
  static const Color tertiaryContainer = Color(0xFFFFD8E4);
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color onTertiaryContainer = Color(0xFF31111D);

  // Error colors
  static const Color error = Color(0xFFB3261E);
  static const Color errorContainer = Color(0xFFF9DEDC);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color onErrorContainer = Color(0xFF410E0B);

  // Success colors
  static const Color success = Color(0xFF4CAF50);
  static const Color successContainer = Color(0xFFC8E6C9);
  static const Color onSuccess = Color(0xFFFFFFFF);

  // Warning colors
  static const Color warning = Color(0xFFFF9800);
  static const Color warningContainer = Color(0xFFFFE0B2);
  static const Color onWarning = Color(0xFFFFFFFF);

  // Neutral colors
  static const Color background = Color(0xFFFFFBFE);
  static const Color onBackground = Color(0xFF1C1B1F);
  static const Color surface = Color(0xFFFFFBFE);
  static const Color onSurface = Color(0xFF1C1B1F);
  static const Color surfaceVariant = Color(0xFFE7E0EC);
  static const Color onSurfaceVariant = Color(0xFF49454F);
  static const Color outline = Color(0xFF79747E);
  static const Color outlineVariant = Color(0xFFCAC4D0);

  // Dark theme colors
  static const Color backgroundDark = Color(0xFF1C1B1F);
  static const Color onBackgroundDark = Color(0xFFE6E1E5);
  static const Color surfaceDark = Color(0xFF1C1B1F);
  static const Color onSurfaceDark = Color(0xFFE6E1E5);
  static const Color primaryDark = Color(0xFFD0BCFF);
  static const Color onPrimaryDark = Color(0xFF381E72);

  // Airo Cyber colors
  static const Color cyberBackground = Color(0xFF041C1C);
  static const Color cyberSurface = Color(0x99041C1C);
  static const Color cyberSurfaceHigh = Color(0x33192424);
  static const Color cyberChrome = Color(0xFF041C1C);
  static const Color cyberPrimary = Color(0xFFFFE6CB);
  static const Color cyberOnPrimary = Color(0xFF041C1C);
  static const Color cyberSecondary = Color(0xFFFFFF89);
  static const Color cyberTertiary = Color(0xFF7FE8DE);
  static const Color cyberText = Color(0xFFFFE6CB);
  static const Color cyberMutedText = Color(0xB3FFE6CB);
  static const Color cyberOutline = Color(0x66FFE6CB);
  static const Color cyberGridLine = Color(0x33FFE6CB);
  static const Color cyberGlow = Color(0x38FFBD38);

  // Cyber semantic surfaces
  static const Color cyberSurfaceSolid = Color(0xFF0A2020);
  static const Color cyberSurfaceRaised = Color(0xFF0F2828);

  // Live / status
  static const Color live = Color(0xFFE53935);
  static const Color liveGlow = Color(0x66E53935);
  static const Color cyberError = Color(0xFFFF6B6B);

  // Bedtime colors
  static const Color bedtimeBackground = Color(0xFF000000);
  static const Color bedtimeSurface = Color(0xFF1A1A1A);
  static const Color bedtimeSurfaceMid = Color(0xFF2D2D2D);
  static const Color bedtimePrimary = Color(0xFFFFE4B5);
  static const Color bedtimeSecondary = Color(0xFFFFD699);
  static const Color bedtimeOnPrimary = Color(0xFF000000);
  static const Color bedtimeError = Color(0xFFCF6679);

  // Airo TV colors — Apple TV / Linear-style design system: one primary
  // accent (emerald) plus a small set of semantic colors, rather than the
  // design handoff's many different shades of green.
  static const Color airoTvBackground = Color(0xFF090B0D);
  static const Color airoTvSurface = Color(0xFF13161B);
  static const Color airoTvSurfaceHigh = Color(0xFF1B2027);
  // Sidebar/chrome gets its own slightly-lighter-than-background tone so it
  // reads as a distinct rail rather than blending into the page.
  static const Color airoTvChrome = Color(0xFF0D1014);
  static const Color airoTvBorder = Color(0xFF2A3038);
  static const Color airoTvPrimary = Color(0xFF3DDC84);
  static const Color airoTvPrimaryHover = Color(0xFF5BE89B);
  static const Color airoTvSelected = Color(0xFF2EBE72);
  static const Color airoTvOnPrimary = Color(0xFF08120C);
  static const Color airoTvPrimaryContainer = Color(0xFF16261C);
  static const Color airoTvSecondary = Color(0xFFC9A167);
  static const Color airoTvOnSecondary = Color(0xFF08120C);
  static const Color airoTvText = Color(0xFFF5F7FA);
  static const Color airoTvMutedText = Color(0xFF9AA3AF);
  static const Color airoTvDisabledText = Color(0xFF5A6573);
  static const Color airoTvOutline = Color(0xFF2A3038);
  static const Color airoTvGridLine = Color(0xFF2A3038);
  static const Color airoTvGlow = Color(0x593DDC84);
  static const Color airoTvLive = Color(0xFFEF4444);
  static const Color airoTvError = Color(0xFFEF4444);
  static const Color airoTvWarning = Color(0xFFF59E0B);
  static const Color airoTvInfo = Color(0xFF3B82F6);

  /// Per-category accent colors (icon/top-border only — never a full fill)
  /// so category identity doesn't rely on shading green differently.
  static const Color airoTvCategoryNews = Color(0xFF3B82F6);
  static const Color airoTvCategorySports = Color(0xFF22C55E);
  static const Color airoTvCategoryMovies = Color(0xFFA855F7);
  static const Color airoTvCategoryMusic = Color(0xFFEC4899);
  static const Color airoTvCategoryKids = Color(0xFFF59E0B);
  static const Color airoTvCategoryDocumentary = Color(0xFF14B8A6);
  static const Color airoTvCategoryEntertainment = Color(0xFFEF4444);
  static const Color airoTvCategoryDefault = Color(0xFF9AA3AF);
}
