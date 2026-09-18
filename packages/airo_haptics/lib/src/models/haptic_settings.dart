import 'package:equatable/equatable.dart';

/// Global configuration settings for the Airo Haptics engine.
class AiroHapticSettings extends Equatable {
  const AiroHapticSettings({
    this.enabled = true,
    this.globalScale = 1.0,
    this.respectSystemSettings = true,
    this.reducedMotion = false,
    this.debugLogs = false,
    this.minThrottleDuration = const Duration(milliseconds: 30),
    this.coalesceInterval = const Duration(milliseconds: 16),
  })  : assert(globalScale >= 0.0 && globalScale <= 1.0, 'Global scale must be between 0.0 and 1.0');

  factory AiroHapticSettings.fromJson(Map<String, dynamic> json) {
    return AiroHapticSettings(
      enabled: json['enabled'] as bool? ?? true,
      globalScale: (json['globalScale'] as num?)?.toDouble() ?? 1.0,
      respectSystemSettings: json['respectSystemSettings'] as bool? ?? true,
      reducedMotion: json['reducedMotion'] as bool? ?? false,
      debugLogs: json['debugLogs'] as bool? ?? false,
      minThrottleDuration: Duration(milliseconds: json['minThrottleDurationMs'] as int? ?? 30),
      coalesceInterval: Duration(milliseconds: json['coalesceIntervalMs'] as int? ?? 16),
    );
  }

  /// Master toggle enabling or disabling all haptic output globally.
  final bool enabled;

  /// Master volume/intensity scale factor (0.0 to 1.0).
  final double globalScale;

  /// Whether to respect OS-level system haptic accessibility settings.
  final bool respectSystemSettings;

  /// Accessibility: whether reduced motion is active (mutes/scales heavy haptics).
  final bool reducedMotion;

  /// Enable detailed logging for debugging haptic timing and dispatch.
  final bool debugLogs;

  /// Default minimum duration window between identical haptic triggers.
  final Duration minThrottleDuration;

  /// Coalescing interval window for grouping rapid consecutive taps.
  final Duration coalesceInterval;

  AiroHapticSettings copyWith({
    bool? enabled,
    double? globalScale,
    bool? respectSystemSettings,
    bool? reducedMotion,
    bool? debugLogs,
    Duration? minThrottleDuration,
    Duration? coalesceInterval,
  }) {
    return AiroHapticSettings(
      enabled: enabled ?? this.enabled,
      globalScale: globalScale ?? this.globalScale,
      respectSystemSettings: respectSystemSettings ?? this.respectSystemSettings,
      reducedMotion: reducedMotion ?? this.reducedMotion,
      debugLogs: debugLogs ?? this.debugLogs,
      minThrottleDuration: minThrottleDuration ?? this.minThrottleDuration,
      coalesceInterval: coalesceInterval ?? this.coalesceInterval,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'globalScale': globalScale,
        'respectSystemSettings': respectSystemSettings,
        'reducedMotion': reducedMotion,
        'debugLogs': debugLogs,
        'minThrottleDurationMs': minThrottleDuration.inMilliseconds,
        'coalesceIntervalMs': coalesceInterval.inMilliseconds,
      };

  @override
  List<Object?> get props => [
        enabled,
        globalScale,
        respectSystemSettings,
        reducedMotion,
        debugLogs,
        minThrottleDuration,
        coalesceInterval,
      ];
}
