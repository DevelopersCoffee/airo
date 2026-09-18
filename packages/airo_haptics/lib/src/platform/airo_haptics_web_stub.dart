import '../models/haptic_capabilities.dart';
import '../models/haptic_diagnostics.dart';
import '../models/haptic_intent.dart';
import '../models/haptic_options.dart';
import '../models/haptic_pattern.dart';
import '../models/haptic_settings.dart';
import 'airo_haptics_platform.dart';

/// The web stub implementation of [AiroHapticsPlatform] for non-web environments.
class AiroHapticsWeb extends AiroHapticsPlatform {
  /// Constructs an [AiroHapticsWeb].
  AiroHapticsWeb();

  /// Registers this class as the default instance of [AiroHapticsPlatform].
  static void registerWith(dynamic registrar) {
    AiroHapticsPlatform.instance = AiroHapticsWeb();
  }

  @override
  Future<AiroHapticCapabilities> getCapabilities() async {
    return const AiroHapticCapabilities.unsupported(
      platform: AiroHapticDevicePlatform.web,
      backend: 'web_vibration_api_stub',
    );
  }

  @override
  Future<void> performFeedback(
    AiroHapticFeedbackType type, {
    AiroHapticOptions? options,
  }) async {}

  @override
  Future<void> performImpact(
    AiroHapticImpact impact, {
    double? intensity,
    AiroHapticOptions? options,
  }) async {}

  @override
  Future<void> playPattern(
    AiroHapticPattern pattern, {
    AiroHapticOptions? options,
  }) async {}

  @override
  Future<void> stopPattern(String patternId) async {}

  @override
  Future<void> stopAll() async {}

  @override
  Future<void> updateSettings(AiroHapticSettings settings) async {}

  @override
  Future<AiroHapticDiagnostics> getDiagnostics() async {
    return AiroHapticDiagnostics(
      activeBackend: 'web_vibration_api_stub',
      totalTriggers: 0,
      playedCount: 0,
      droppedCount: 0,
      lastTriggerTimestamp: DateTime.now(),
    );
  }
}
