import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

import '../models/haptic_capabilities.dart';
import '../models/haptic_diagnostics.dart';
import '../models/haptic_intent.dart';
import '../models/haptic_options.dart';
import '../models/haptic_pattern.dart';
import '../models/haptic_settings.dart';
import 'airo_haptics_platform.dart';

@JS('navigator.vibrate')
external bool _jsVibrate(JSAny pattern);

/// The web implementation of [AiroHapticsPlatform].
class AiroHapticsWeb extends AiroHapticsPlatform {
  /// Constructs an [AiroHapticsWeb].
  AiroHapticsWeb();

  /// Registers this class as the default instance of [AiroHapticsPlatform].
  static void registerWith(Registrar registrar) {
    AiroHapticsPlatform.instance = AiroHapticsWeb();
  }

  bool get _isVibrateSupported {
    try {
      final hasNav = globalContext.hasProperty('navigator'.toJS);
      if (!hasNav.toDart) return false;
      final nav = globalContext.getProperty('navigator'.toJS);
      if (nav == null || !nav.isA<JSObject>()) return false;
      final hasVib = (nav as JSObject).hasProperty('vibrate'.toJS);
      return hasVib.toDart;
    } catch (_) {
      return false;
    }
  }

  void _vibrate(JSAny pattern) {
    if (!_isVibrateSupported) return;
    try {
      _jsVibrate(pattern);
    } catch (_) {}
  }

  @override
  Future<AiroHapticCapabilities> getCapabilities() async {
    final supported = _isVibrateSupported;
    if (supported) {
      return const AiroHapticCapabilities.basicOnly(
        platform: AiroHapticDevicePlatform.web,
        backend: 'web_vibration_api',
      );
    }
    return const AiroHapticCapabilities.unsupported(
      platform: AiroHapticDevicePlatform.web,
      backend: 'web_vibration_api',
    );
  }

  @override
  Future<void> performFeedback(
    AiroHapticFeedbackType type, {
    AiroHapticOptions? options,
  }) async {
    final pattern = _mapFeedbackTypeToPattern(type);
    if (pattern.length == 1) {
      _vibrate(pattern.first.toJS);
    } else if (pattern.length > 1) {
      _vibrate(pattern.map((e) => e.toJS).toList().toJS);
    }
  }

  @override
  Future<void> performImpact(
    AiroHapticImpact impact, {
    double? intensity,
    AiroHapticOptions? options,
  }) async {
    final baseDuration = switch (impact) {
      AiroHapticImpact.light => 15,
      AiroHapticImpact.medium => 30,
      AiroHapticImpact.heavy => 50,
      AiroHapticImpact.rigid => 20,
      AiroHapticImpact.soft => 12,
    };
    final scale = (intensity ?? impact.defaultIntensity).clamp(0.1, 2.0);
    final duration = (baseDuration * scale).round();
    _vibrate(duration.toJS);
  }

  @override
  Future<void> playPattern(
    AiroHapticPattern pattern, {
    AiroHapticOptions? options,
  }) async {
    final sequence = <int>[];
    double currentTime = 0;
    for (final event in pattern.events) {
      final delayMs = event.delay.inMilliseconds;
      final durationMs = event.duration.inMilliseconds > 0
          ? event.duration.inMilliseconds
          : 15;
      final delay = (delayMs - currentTime).clamp(0, 10000).toInt();
      if (delay > 0) {
        if (sequence.isEmpty) {
          sequence.add(0);
        }
        sequence.add(delay);
      }
      sequence.add(durationMs);
      currentTime = delayMs.toDouble() + durationMs;
    }
    if (sequence.isNotEmpty) {
      _vibrate(sequence.map((e) => e.toJS).toList().toJS);
    }
  }

  @override
  Future<void> stopPattern(String patternId) async {
    await stopAll();
  }

  @override
  Future<void> stopAll() async {
    _vibrate(0.toJS);
  }

  @override
  Future<void> updateSettings(AiroHapticSettings settings) async {}

  @override
  Future<AiroHapticDiagnostics> getDiagnostics() async {
    return AiroHapticDiagnostics(
      activeBackend: 'web_vibration_api',
      totalTriggers: 0,
      playedCount: 0,
      droppedCount: 0,
      lastTriggerTimestamp: DateTime.now(),
    );
  }

  List<int> _mapFeedbackTypeToPattern(AiroHapticFeedbackType type) {
    return switch (type) {
      AiroHapticFeedbackType.selection => [10],
      AiroHapticFeedbackType.focus => [15],
      AiroHapticFeedbackType.press => [20],
      AiroHapticFeedbackType.longPress => [60],
      AiroHapticFeedbackType.dragStart => [25],
      AiroHapticFeedbackType.dragEnd => [30],
      AiroHapticFeedbackType.impact => [35],
      AiroHapticFeedbackType.notification => [40, 50, 40],
      AiroHapticFeedbackType.success => [20, 40, 30],
      AiroHapticFeedbackType.warning => [40, 40, 40],
      AiroHapticFeedbackType.error => [60, 50, 60, 50, 60],
      AiroHapticFeedbackType.confirm => [25, 30, 25],
      AiroHapticFeedbackType.reject => [50, 50, 50],
      AiroHapticFeedbackType.delete => [70, 40, 30],
      AiroHapticFeedbackType.refresh => [15, 30, 15],
      AiroHapticFeedbackType.completion => [30, 40, 50],
      AiroHapticFeedbackType.failure => [80, 50, 80],
      AiroHapticFeedbackType.boundary => [10],
      AiroHapticFeedbackType.navigation => [15],
      AiroHapticFeedbackType.toggleOn => [20, 30, 40],
      AiroHapticFeedbackType.toggleOff => [40, 30, 20],
    };
  }
}
