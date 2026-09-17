import 'package:equatable/equatable.dart';
import 'haptic_intent.dart';

/// Options for configuring single haptic execution calls.
class AiroHapticOptions extends Equatable {
  const AiroHapticOptions({
    this.intensity,
    this.sharpness,
    this.priority = AiroHapticPriority.normal,
    this.cooldown,
    this.tag,
    this.audioSync = false,
  })  : assert(intensity == null || (intensity >= 0.0 && intensity <= 1.0), 'Intensity must be between 0.0 and 1.0'),
        assert(sharpness == null || (sharpness >= 0.0 && sharpness <= 1.0), 'Sharpness must be between 0.0 and 1.0');

  factory AiroHapticOptions.fromJson(Map<String, dynamic> json) {
    return AiroHapticOptions(
      intensity: (json['intensity'] as num?)?.toDouble(),
      sharpness: (json['sharpness'] as num?)?.toDouble(),
      priority: AiroHapticPriority.values.byName(json['priority'] as String? ?? 'normal'),
      cooldown: json['cooldownMs'] != null ? Duration(milliseconds: json['cooldownMs'] as int) : null,
      tag: json['tag'] as String?,
      audioSync: json['audioSync'] as bool? ?? false,
    );
  }

  /// Optional relative intensity multiplier/override (0.0 to 1.0).
  final double? intensity;

  /// Optional relative sharpness override (0.0 to 1.0).
  final double? sharpness;

  /// Priority of this haptic invocation.
  final AiroHapticPriority priority;

  /// Minimum delay before another feedback with the same tag or type can fire.
  final Duration? cooldown;

  /// Custom tag or identifier for coalescing / throttling.
  final String? tag;

  /// Whether to synchronize with platform audio feedback if available.
  final bool audioSync;

  Map<String, dynamic> toJson() => {
        'intensity': intensity,
        'sharpness': sharpness,
        'priority': priority.name,
        'cooldownMs': cooldown?.inMilliseconds,
        'tag': tag,
        'audioSync': audioSync,
      };

  @override
  List<Object?> get props => [intensity, sharpness, priority, cooldown, tag, audioSync];
}
