import 'package:flutter/material.dart';

import 'airo_motion.dart';

/// Product moods supported by the Airo Living Console.
///
/// A mood changes one accent pair only. It never redefines semantic success,
/// warning, error, or live-state colors.
enum AiroDomain {
  airo,
  money,
  mind,
  beats,
  live,
  arena,
  quest,
  reader,
  neutral,
}

@immutable
class AiroDomainTokens extends ThemeExtension<AiroDomainTokens> {
  const AiroDomainTokens({
    required this.domain,
    required this.accent,
    required this.accentSecondary,
    required this.onAccent,
  });

  final AiroDomain domain;
  final Color accent;
  final Color accentSecondary;
  final Color onAccent;

  LinearGradient get gradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accent, accentSecondary],
  );

  static const palettes = <AiroDomain, AiroDomainTokens>{
    AiroDomain.airo: AiroDomainTokens(
      domain: AiroDomain.airo,
      accent: Color(0xFF5CE1E6),
      accentSecondary: Color(0xFF9B8CFF),
      onAccent: Color(0xFF041014),
    ),
    AiroDomain.money: AiroDomainTokens(
      domain: AiroDomain.money,
      accent: Color(0xFF47D7A0),
      accentSecondary: Color(0xFF78E7C0),
      onAccent: Color(0xFF03150E),
    ),
    AiroDomain.mind: AiroDomainTokens(
      domain: AiroDomain.mind,
      accent: Color(0xFFA998FF),
      accentSecondary: Color(0xFF6FD6FF),
      onAccent: Color(0xFF0C071C),
    ),
    AiroDomain.beats: AiroDomainTokens(
      domain: AiroDomain.beats,
      accent: Color(0xFFFF78C8),
      accentSecondary: Color(0xFFA998FF),
      onAccent: Color(0xFF1A0612),
    ),
    AiroDomain.live: AiroDomainTokens(
      domain: AiroDomain.live,
      accent: Color(0xFF45D98A),
      accentSecondary: Color(0xFF5CE1E6),
      onAccent: Color(0xFF03150C),
    ),
    AiroDomain.arena: AiroDomainTokens(
      domain: AiroDomain.arena,
      accent: Color(0xFFFFC857),
      accentSecondary: Color(0xFFFF8A5B),
      onAccent: Color(0xFF1B1000),
    ),
    AiroDomain.quest: AiroDomainTokens(
      domain: AiroDomain.quest,
      accent: Color(0xFFFF8A78),
      accentSecondary: Color(0xFFFFC857),
      onAccent: Color(0xFF1C0804),
    ),
    AiroDomain.reader: AiroDomainTokens(
      domain: AiroDomain.reader,
      accent: Color(0xFFF1DFC0),
      accentSecondary: Color(0xFFD8C49D),
      onAccent: Color(0xFF171007),
    ),
    AiroDomain.neutral: AiroDomainTokens(
      domain: AiroDomain.neutral,
      accent: Color(0xFF8FDDE0),
      accentSecondary: Color(0xFFAEB8C2),
      onAccent: Color(0xFF061113),
    ),
  };

  static AiroDomainTokens forDomain(AiroDomain domain) => palettes[domain]!;

  static AiroDomainTokens of(BuildContext context) {
    return Theme.of(context).extension<AiroDomainTokens>() ??
        forDomain(AiroDomain.airo);
  }

  @override
  AiroDomainTokens copyWith({
    AiroDomain? domain,
    Color? accent,
    Color? accentSecondary,
    Color? onAccent,
  }) {
    return AiroDomainTokens(
      domain: domain ?? this.domain,
      accent: accent ?? this.accent,
      accentSecondary: accentSecondary ?? this.accentSecondary,
      onAccent: onAccent ?? this.onAccent,
    );
  }

  @override
  AiroDomainTokens lerp(covariant AiroDomainTokens? other, double t) {
    if (other == null) return this;
    return AiroDomainTokens(
      domain: t < 0.5 ? domain : other.domain,
      accent: Color.lerp(accent, other.accent, t)!,
      accentSecondary: Color.lerp(accentSecondary, other.accentSecondary, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
    );
  }
}

/// Applies a single product-domain mood while preserving the active global
/// theme's geometry, typography, and semantic colors.
class AiroDomainTheme extends StatelessWidget {
  const AiroDomainTheme({required this.domain, required this.child, super.key});

  final AiroDomain domain;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final tokens = AiroDomainTokens.forDomain(domain);
    final scheme = base.colorScheme.copyWith(
      primary: tokens.accent,
      onPrimary: tokens.onAccent,
      primaryContainer: Color.alphaBlend(
        tokens.accent.withValues(alpha: 0.14),
        base.colorScheme.surface,
      ),
      onPrimaryContainer: base.colorScheme.onSurface,
      secondary: tokens.accentSecondary,
      onSecondary: tokens.onAccent,
      secondaryContainer: Color.alphaBlend(
        tokens.accentSecondary.withValues(alpha: 0.12),
        base.colorScheme.surface,
      ),
      onSecondaryContainer: base.colorScheme.onSurface,
    );
    final extensions =
        base.extensions.values
            .where((extension) => extension is! AiroDomainTokens)
            .toList()
          ..add(tokens);

    return AnimatedTheme(
      data: base.copyWith(colorScheme: scheme, extensions: extensions),
      duration: AiroMotion.resolve(context, AiroMotion.standard),
      curve: AiroMotion.emphasis,
      child: child,
    );
  }
}
