import 'package:equatable/equatable.dart';

/// Type of haptic event element.
enum AiroHapticEventType {
  transient,
  continuous,
}

/// Represents an individual haptic pulse or continuous vibration event in a pattern.
class AiroHapticEvent extends Equatable {
  const AiroHapticEvent({
    required this.type,
    this.intensity = 1.0,
    this.sharpness = 0.5,
    this.duration = Duration.zero,
    this.delay = Duration.zero,
  })  : assert(intensity >= 0.0 && intensity <= 1.0, 'Intensity must be between 0.0 and 1.0'),
        assert(sharpness >= 0.0 && sharpness <= 1.0, 'Sharpness must be between 0.0 and 1.0');

  /// Creates a transient (impulse/click) haptic event.
  const AiroHapticEvent.transient({
    double intensity = 1.0,
    double sharpness = 0.5,
    Duration delay = Duration.zero,
    Duration? at,
  }) : this(
          type: AiroHapticEventType.transient,
          intensity: intensity,
          sharpness: sharpness,
          duration: Duration.zero,
          delay: at ?? delay,
        );

  /// Creates a continuous sustained haptic event.
  const AiroHapticEvent.continuous({
    required Duration duration,
    double intensity = 1.0,
    double sharpness = 0.5,
    Duration delay = Duration.zero,
    Duration? at,
  }) : this(
          type: AiroHapticEventType.continuous,
          intensity: intensity,
          sharpness: sharpness,
          duration: duration,
          delay: at ?? delay,
        );

  factory AiroHapticEvent.fromJson(Map<String, dynamic> json) {
    return AiroHapticEvent(
      type: AiroHapticEventType.values.byName(json['type'] as String),
      intensity: (json['intensity'] as num).toDouble(),
      sharpness: (json['sharpness'] as num).toDouble(),
      duration: Duration(milliseconds: json['durationMs'] as int),
      delay: Duration(milliseconds: json['delayMs'] as int),
    );
  }

  final AiroHapticEventType type;
  final double intensity;
  final double sharpness;
  final Duration duration;
  final Duration delay;

  /// Timestamp offset alias within a pattern.
  Duration get atOffset => delay;

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'intensity': intensity,
        'sharpness': sharpness,
        'durationMs': duration.inMilliseconds,
        'delayMs': delay.inMilliseconds,
      };

  @override
  List<Object?> get props => [type, intensity, sharpness, duration, delay];
}
