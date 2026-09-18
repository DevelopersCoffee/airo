import '../models/haptic_capabilities.dart';
import '../models/haptic_intent.dart';
import '../models/haptic_options.dart';
import '../models/haptic_settings.dart';
import '../models/haptic_theme.dart';

/// Resolved execution decisions for haptic feedback.
class ResolvedHapticDecision {
  const ResolvedHapticDecision({
    required this.shouldPlay,
    required this.effectiveIntensity,
    required this.effectiveSharpness,
    required this.priority,
    this.reason,
  });

  const ResolvedHapticDecision.skip(this.reason)
      : shouldPlay = false,
        effectiveIntensity = 0.0,
        effectiveSharpness = 0.0,
        priority = AiroHapticPriority.low;

  final bool shouldPlay;
  final double effectiveIntensity;
  final double effectiveSharpness;
  final AiroHapticPriority priority;
  final String? reason;
}

/// Computes execution parameters based on capabilities, settings, theme, and call options.
class AiroHapticResolver {
  const AiroHapticResolver();

  ResolvedHapticDecision resolve({
    required AiroHapticCapabilities capabilities,
    required AiroHapticSettings settings,
    required AiroHapticTheme theme,
    required double baseIntensity,
    required double baseSharpness,
    AiroHapticOptions? options,
  }) {
    if (!settings.enabled) {
      return const ResolvedHapticDecision.skip('Engine disabled globally in settings');
    }

    if (!capabilities.supported) {
      return const ResolvedHapticDecision.skip('Hardware or platform does not support haptics');
    }

    final priority = options?.priority ?? AiroHapticPriority.normal;
    final requestedIntensity = options?.intensity ?? baseIntensity;
    final requestedSharpness = options?.sharpness ?? baseSharpness;

    final reducedScale = settings.reducedMotion ? 0.5 : 1.0;
    final effectiveIntensity = (requestedIntensity * settings.globalScale * theme.intensityScale * reducedScale)
        .clamp(0.0, 1.0);
    final effectiveSharpness = requestedSharpness.clamp(0.0, 1.0);

    if (effectiveIntensity <= 0.0) {
      return const ResolvedHapticDecision.skip('Effective intensity evaluated to 0.0');
    }

    return ResolvedHapticDecision(
      shouldPlay: true,
      effectiveIntensity: effectiveIntensity,
      effectiveSharpness: effectiveSharpness,
      priority: priority,
    );
  }
}
