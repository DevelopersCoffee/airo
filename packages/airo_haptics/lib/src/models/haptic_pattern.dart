import 'package:equatable/equatable.dart';
import 'haptic_event.dart';

/// Validation result for custom haptic patterns.
class AiroHapticPatternValidationResult extends Equatable {
  const AiroHapticPatternValidationResult({
    required this.isValid,
    this.errors = const [],
  });

  final bool isValid;
  final List<String> errors;

  @override
  List<Object?> get props => [isValid, errors];
}

/// Represents a composite sequence of haptic events (custom pattern or preset wave).
class AiroHapticPattern extends Equatable {
  const AiroHapticPattern({
    required this.id,
    required this.events,
    this.name,
    this.loop = false,
  });

  /// Preset pattern: Double click impulse.
  factory AiroHapticPattern.doubleClick({String id = 'preset_double_click'}) {
    return AiroHapticPattern(
      id: id,
      name: 'Double Click',
      events: const [
        AiroHapticEvent.transient(intensity: 0.6, sharpness: 0.7),
        AiroHapticEvent.transient(intensity: 0.8, sharpness: 0.8, delay: Duration(milliseconds: 60)),
      ],
    );
  }

  /// Preset pattern: Success pulse wave.
  factory AiroHapticPattern.successWave({String id = 'preset_success_wave'}) {
    return AiroHapticPattern(
      id: id,
      name: 'Success Wave',
      events: const [
        AiroHapticEvent.transient(intensity: 0.4, sharpness: 0.3),
        AiroHapticEvent.transient(intensity: 0.9, sharpness: 0.9, delay: Duration(milliseconds: 80)),
      ],
    );
  }

  /// Preset pattern: Error triple pulse.
  factory AiroHapticPattern.errorAlert({String id = 'preset_error_alert'}) {
    return AiroHapticPattern(
      id: id,
      name: 'Error Alert',
      events: const [
        AiroHapticEvent.transient(sharpness: 0.9),
        AiroHapticEvent.transient(intensity: 0.8, sharpness: 0.9, delay: Duration(milliseconds: 70)),
        AiroHapticEvent.transient(sharpness: 0.9, delay: Duration(milliseconds: 70)),
      ],
    );
  }

  /// Preset pattern: Heartbeat pulse.
  factory AiroHapticPattern.heartbeat({String id = 'preset_heartbeat'}) {
    return AiroHapticPattern(
      id: id,
      name: 'Heartbeat',
      events: const [
        AiroHapticEvent.transient(intensity: 0.8, sharpness: 0.2),
        AiroHapticEvent.transient(intensity: 0.5, sharpness: 0.2, delay: Duration(milliseconds: 120)),
      ],
    );
  }

  /// Preset pattern: Ramp up continuous vibration.
  factory AiroHapticPattern.rampUp({String id = 'preset_ramp_up', Duration duration = const Duration(milliseconds: 300)}) {
    return AiroHapticPattern(
      id: id,
      name: 'Ramp Up',
      events: [
        AiroHapticEvent.continuous(duration: duration, intensity: 0.3, sharpness: 0.2),
        const AiroHapticEvent.transient(sharpness: 0.9, delay: Duration(milliseconds: 10)),
      ],
    );
  }

  factory AiroHapticPattern.fromJson(Map<String, dynamic> json) {
    return AiroHapticPattern(
      id: json['id'] as String,
      name: json['name'] as String?,
      loop: json['loop'] as bool? ?? false,
      events: (json['events'] as List<dynamic>)
          .map((e) => AiroHapticEvent.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  final String id;
  final String? name;
  final List<AiroHapticEvent> events;
  final bool loop;

  /// Calculates total duration of the pattern including event delays and durations.
  Duration get totalDuration {
    var totalMs = 0;
    for (final event in events) {
      totalMs += event.delay.inMilliseconds + event.duration.inMilliseconds;
    }
    return Duration(milliseconds: totalMs);
  }

  /// Validates pattern integrity.
  AiroHapticPatternValidationResult validate() {
    final errors = <String>[];
    if (events.isEmpty) {
      errors.add('Pattern must contain at least one event');
    }
    for (var i = 0; i < events.length; i++) {
      final e = events[i];
      if (e.delay.isNegative) {
        errors.add('Event #$i has negative delay: ${e.delay}');
      }
      if (e.intensity < 0.0 || e.intensity > 1.0) {
        errors.add('Event #$i has invalid intensity: ${e.intensity}');
      }
    }
    return AiroHapticPatternValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'loop': loop,
        'events': events.map((e) => e.toJson()).toList(),
      };

  @override
  List<Object?> get props => [id, name, events, loop];
}
