import '../models/haptic_capabilities.dart';
import '../models/haptic_diagnostics.dart';
import '../models/haptic_intent.dart';
import '../models/haptic_options.dart';
import '../models/haptic_pattern.dart';
import '../models/haptic_settings.dart';
import '../platform/airo_haptics_platform.dart';

/// Recorded haptic invocation record for test assertions.
class HapticInvocation {
  const HapticInvocation({
    required this.method,
    this.feedbackType,
    this.impact,
    this.pattern,
    this.intensity,
    this.sharpness,
    this.options,
    this.timestamp,
  });

  final String method;
  final AiroHapticFeedbackType? feedbackType;
  final AiroHapticImpact? impact;
  final AiroHapticPattern? pattern;
  final double? intensity;
  final double? sharpness;
  final AiroHapticOptions? options;
  final DateTime? timestamp;
}

/// Fake implementation of [AiroHapticsPlatform] for unit and widget testing.
class FakeAiroHapticPlatform extends AiroHapticsPlatform {
  FakeAiroHapticPlatform({
    this.capabilities = const AiroHapticCapabilities.full(
      platform: AiroHapticDevicePlatform.ios,
      backend: 'fake_test_backend',
    ),
  });

  AiroHapticCapabilities capabilities;
  AiroHapticSettings settings = const AiroHapticSettings();
  final List<HapticInvocation> invocations = [];

  bool isStopped = false;

  void clearInvocations() {
    invocations.clear();
    isStopped = false;
  }

  /// Helper assertion: verifies a semantic feedback type was performed.
  void expectHapticPlayed(AiroHapticFeedbackType type) {
    final match = invocations.any((inv) => inv.feedbackType == type);
    if (!match) {
      throw StateError('Expected haptic feedback ${type.name} to be played');
    }
  }

  /// Helper assertion: verifies no haptic feedback was triggered.
  void expectNoHapticPlayed() {
    final played = invocations.any(
      (inv) => inv.method == 'performFeedback' || inv.method == 'performImpact' || inv.method == 'playPattern',
    );
    if (played) {
      throw StateError('Expected no haptic feedback to be played');
    }
  }

  /// Helper assertion: verifies a pattern with id [patternId] was played.
  void expectHapticPatternPlayed(String patternId) {
    final match = invocations.any((inv) => inv.pattern?.id == patternId);
    if (!match) {
      throw StateError('Expected haptic pattern $patternId to be played');
    }
  }

  @override
  Future<AiroHapticCapabilities> getCapabilities() async {
    return capabilities;
  }

  @override
  Future<void> performFeedback(
    AiroHapticFeedbackType type, {
    AiroHapticOptions? options,
  }) async {
    invocations.add(HapticInvocation(
      method: 'performFeedback',
      feedbackType: type,
      options: options,
      timestamp: DateTime.now(),
    ));
  }

  @override
  Future<void> performImpact(
    AiroHapticImpact impact, {
    double? intensity,
    AiroHapticOptions? options,
  }) async {
    invocations.add(HapticInvocation(
      method: 'performImpact',
      impact: impact,
      intensity: intensity ?? impact.defaultIntensity,
      options: options,
      timestamp: DateTime.now(),
    ));
  }

  @override
  Future<void> playPattern(
    AiroHapticPattern pattern, {
    AiroHapticOptions? options,
  }) async {
    invocations.add(HapticInvocation(
      method: 'playPattern',
      pattern: pattern,
      options: options,
      timestamp: DateTime.now(),
    ));
  }

  @override
  Future<void> updatePattern(String patternId, double intensity, double sharpness) async {
    invocations.add(HapticInvocation(
      method: 'updatePattern',
      intensity: intensity,
      sharpness: sharpness,
      timestamp: DateTime.now(),
    ));
  }

  @override
  Future<void> stopPattern(String patternId) async {
    invocations.add(HapticInvocation(
      method: 'stopPattern',
      timestamp: DateTime.now(),
    ));
  }

  @override
  Future<void> stopAll() async {
    isStopped = true;
    invocations.add(HapticInvocation(
      method: 'stopAll',
      timestamp: DateTime.now(),
    ));
  }

  @override
  Future<void> updateSettings(AiroHapticSettings settings) async {
    this.settings = settings;
    invocations.add(HapticInvocation(
      method: 'updateSettings',
      timestamp: DateTime.now(),
    ));
  }

  @override
  Future<AiroHapticDiagnostics> getDiagnostics() async {
    return AiroHapticDiagnostics(
      totalTriggers: invocations.length,
      playedCount: invocations.where((i) => i.method != 'stopAll' && i.method != 'updateSettings').length,
      droppedCount: 0,
      activeBackend: capabilities.backend ?? 'fake_test_backend',
      lastTriggeredType: invocations.isNotEmpty ? invocations.last.method : null,
      lastTriggerTimestamp: invocations.isNotEmpty ? invocations.last.timestamp : null,
    );
  }
}

/// Helper assertion: verifies a semantic feedback type was performed on [fake].
void expectHapticPlayed(FakeAiroHapticPlatform fake, AiroHapticFeedbackType type) => fake.expectHapticPlayed(type);

/// Helper assertion: verifies no haptic feedback was triggered on [fake].
void expectNoHapticPlayed(FakeAiroHapticPlatform fake) => fake.expectNoHapticPlayed();

/// Helper assertion: verifies a pattern with id [patternId] was played on [fake].
void expectHapticPatternPlayed(FakeAiroHapticPlatform fake, String patternId) => fake.expectHapticPatternPlayed(patternId);

/// Type aliases for testing convenience.
typedef FakeAiroHaptics = FakeAiroHapticPlatform;
typedef RecordingHapticBackend = FakeAiroHapticPlatform;
typedef RecordingAiroHaptics = FakeAiroHapticPlatform;
