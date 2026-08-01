import 'package:flutter/material.dart';

/// Ambient Precision visual foundations that are not represented by Material's
/// [ColorScheme].
///
/// These tokens keep surface depth and geometry consistent across Airo's
/// product domains. Domain identity belongs to [AiroDomainTokens], while
/// semantic status colors remain in [ColorScheme].
@immutable
class AiroVisualTokens extends ThemeExtension<AiroVisualTokens> {
  const AiroVisualTokens({
    required this.canvas,
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceFloating,
    required this.surfaceGlass,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
    required this.identityStart,
    required this.identityEnd,
    required this.radiusSmall,
    required this.radiusMedium,
    required this.radiusLarge,
    required this.radiusExtraLarge,
  });

  final Color canvas;
  final Color surface;
  final Color surfaceRaised;
  final Color surfaceFloating;
  final Color surfaceGlass;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;
  final Color identityStart;
  final Color identityEnd;
  final double radiusSmall;
  final double radiusMedium;
  final double radiusLarge;
  final double radiusExtraLarge;

  LinearGradient get ambientGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      canvas,
      Color.alphaBlend(identityStart.withValues(alpha: 0.05), canvas),
    ],
  );

  LinearGradient get identityGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [identityStart, identityEnd],
  );

  BorderRadius get smallRadius => BorderRadius.circular(radiusSmall);
  BorderRadius get mediumRadius => BorderRadius.circular(radiusMedium);
  BorderRadius get largeRadius => BorderRadius.circular(radiusLarge);
  BorderRadius get extraLargeRadius => BorderRadius.circular(radiusExtraLarge);

  static const livingConsole = AiroVisualTokens(
    canvas: Color(0xFF05080B),
    surface: Color(0xFF0B1116),
    surfaceRaised: Color(0xFF111A21),
    surfaceFloating: Color(0xFF17222B),
    surfaceGlass: Color(0xE60B1116),
    textPrimary: Color(0xFFF4F1EA),
    textSecondary: Color(0xFFAEB8C2),
    border: Color(0x24FFFFFF),
    identityStart: Color(0xFF5CE1E6),
    identityEnd: Color(0xFF9B8CFF),
    radiusSmall: 10,
    radiusMedium: 16,
    radiusLarge: 24,
    radiusExtraLarge: 32,
  );

  static const classicLight = AiroVisualTokens(
    canvas: Color(0xFFFFFBFE),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFF7F2FA),
    surfaceFloating: Color(0xFFF1ECF4),
    surfaceGlass: Color(0xF2FFFFFF),
    textPrimary: Color(0xFF1D1B20),
    textSecondary: Color(0xFF49454F),
    border: Color(0x2979747E),
    identityStart: Color(0xFF6750A4),
    identityEnd: Color(0xFF7D5260),
    radiusSmall: 10,
    radiusMedium: 16,
    radiusLarge: 24,
    radiusExtraLarge: 32,
  );

  static const classicDark = AiroVisualTokens(
    canvas: Color(0xFF121212),
    surface: Color(0xFF1A1A1A),
    surfaceRaised: Color(0xFF222222),
    surfaceFloating: Color(0xFF2A2A2A),
    surfaceGlass: Color(0xE61A1A1A),
    textPrimary: Color(0xFFF4EFF4),
    textSecondary: Color(0xFFC9C3CC),
    border: Color(0x29FFFFFF),
    identityStart: Color(0xFFD0BCFF),
    identityEnd: Color(0xFFEFB8C8),
    radiusSmall: 10,
    radiusMedium: 16,
    radiusLarge: 24,
    radiusExtraLarge: 32,
  );

  static const airoTv = AiroVisualTokens(
    canvas: Color(0xFF030506),
    surface: Color(0xFF090D10),
    surfaceRaised: Color(0xFF10171C),
    surfaceFloating: Color(0xFF172127),
    surfaceGlass: Color(0xEB090D10),
    textPrimary: Color(0xFFF5F7F8),
    textSecondary: Color(0xFFAEB8C2),
    border: Color(0x2EFFFFFF),
    identityStart: Color(0xFF45D98A),
    identityEnd: Color(0xFF5CE1E6),
    radiusSmall: 10,
    radiusMedium: 16,
    radiusLarge: 24,
    radiusExtraLarge: 32,
  );

  static AiroVisualTokens of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<AiroVisualTokens>() ??
        (theme.brightness == Brightness.dark ? livingConsole : classicLight);
  }

  @override
  AiroVisualTokens copyWith({
    Color? canvas,
    Color? surface,
    Color? surfaceRaised,
    Color? surfaceFloating,
    Color? surfaceGlass,
    Color? textPrimary,
    Color? textSecondary,
    Color? border,
    Color? identityStart,
    Color? identityEnd,
    double? radiusSmall,
    double? radiusMedium,
    double? radiusLarge,
    double? radiusExtraLarge,
  }) {
    return AiroVisualTokens(
      canvas: canvas ?? this.canvas,
      surface: surface ?? this.surface,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      surfaceFloating: surfaceFloating ?? this.surfaceFloating,
      surfaceGlass: surfaceGlass ?? this.surfaceGlass,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      border: border ?? this.border,
      identityStart: identityStart ?? this.identityStart,
      identityEnd: identityEnd ?? this.identityEnd,
      radiusSmall: radiusSmall ?? this.radiusSmall,
      radiusMedium: radiusMedium ?? this.radiusMedium,
      radiusLarge: radiusLarge ?? this.radiusLarge,
      radiusExtraLarge: radiusExtraLarge ?? this.radiusExtraLarge,
    );
  }

  @override
  AiroVisualTokens lerp(covariant AiroVisualTokens? other, double t) {
    if (other == null) return this;
    return AiroVisualTokens(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      surfaceFloating: Color.lerp(surfaceFloating, other.surfaceFloating, t)!,
      surfaceGlass: Color.lerp(surfaceGlass, other.surfaceGlass, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      border: Color.lerp(border, other.border, t)!,
      identityStart: Color.lerp(identityStart, other.identityStart, t)!,
      identityEnd: Color.lerp(identityEnd, other.identityEnd, t)!,
      radiusSmall: radiusSmall + (other.radiusSmall - radiusSmall) * t,
      radiusMedium: radiusMedium + (other.radiusMedium - radiusMedium) * t,
      radiusLarge: radiusLarge + (other.radiusLarge - radiusLarge) * t,
      radiusExtraLarge:
          radiusExtraLarge + (other.radiusExtraLarge - radiusExtraLarge) * t,
    );
  }
}
