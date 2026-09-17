import 'package:equatable/equatable.dart';
import 'haptic_intent.dart';
import 'haptic_pattern.dart';

/// Mapping of semantic haptic feedback types to custom patterns or scaling.
class AiroHapticTheme extends Equatable {
  const AiroHapticTheme({
    required this.name,
    this.semanticOverrides = const {},
    this.intensityScale = 1.0,
  });

  /// Standard subtle feedback theme (reduced intensity for clean, quiet UI).
  factory AiroHapticTheme.subtle() => const AiroHapticTheme(
        name: 'subtle',
        intensityScale: 0.5,
      );

  /// Standard default theme.
  factory AiroHapticTheme.standard() => const AiroHapticTheme(
        name: 'standard',
      );

  /// Expressive high-clarity feedback theme for games and rich media.
  factory AiroHapticTheme.expressive() => AiroHapticTheme(
        name: 'expressive',
        semanticOverrides: {
          AiroHapticFeedbackType.success: AiroHapticPattern.successWave(),
          AiroHapticFeedbackType.error: AiroHapticPattern.errorAlert(),
        },
      );

  final String name;
  final Map<AiroHapticFeedbackType, AiroHapticPattern> semanticOverrides;
  final double intensityScale;

  @override
  List<Object?> get props => [name, semanticOverrides, intensityScale];
}
