import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// Settings for context-aware audio behavior
class AudioContextSettings extends Equatable {
  /// Whether context-aware audio is enabled
  final bool enabled;

  /// Ducking volume level (0.1 - 0.5)
  final double duckingLevel;

  /// Whether to duck during AI voice output
  final bool duckDuringVoiceOutput;

  /// Whether to duck during game SFX
  final bool duckDuringGameSfx;

  /// Whether to pause during video playback
  final bool pauseDuringVideo;

  /// Whether to pause during voice input
  final bool pauseDuringVoiceInput;

  /// Bedtime mode settings
  final BedtimeModeSettings bedtimeMode;

  /// Per-feature audio rules
  final Map<String, FeatureAudioRule> featureRules;

  const AudioContextSettings({
    this.enabled = true,
    this.duckingLevel = 0.3,
    this.duckDuringVoiceOutput = true,
    this.duckDuringGameSfx = true,
    this.pauseDuringVideo = true,
    this.pauseDuringVoiceInput = true,
    this.bedtimeMode = const BedtimeModeSettings(),
    this.featureRules = const {},
  });

  /// Default settings
  static const AudioContextSettings defaults = AudioContextSettings();

  AudioContextSettings copyWith({
    bool? enabled,
    double? duckingLevel,
    bool? duckDuringVoiceOutput,
    bool? duckDuringGameSfx,
    bool? pauseDuringVideo,
    bool? pauseDuringVoiceInput,
    BedtimeModeSettings? bedtimeMode,
    Map<String, FeatureAudioRule>? featureRules,
  }) {
    return AudioContextSettings(
      enabled: enabled ?? this.enabled,
      duckingLevel: duckingLevel ?? this.duckingLevel,
      duckDuringVoiceOutput:
          duckDuringVoiceOutput ?? this.duckDuringVoiceOutput,
      duckDuringGameSfx: duckDuringGameSfx ?? this.duckDuringGameSfx,
      pauseDuringVideo: pauseDuringVideo ?? this.pauseDuringVideo,
      pauseDuringVoiceInput:
          pauseDuringVoiceInput ?? this.pauseDuringVoiceInput,
      bedtimeMode: bedtimeMode ?? this.bedtimeMode,
      featureRules: featureRules ?? this.featureRules,
    );
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'duckingLevel': duckingLevel,
    'duckDuringVoiceOutput': duckDuringVoiceOutput,
    'duckDuringGameSfx': duckDuringGameSfx,
    'pauseDuringVideo': pauseDuringVideo,
    'pauseDuringVoiceInput': pauseDuringVoiceInput,
    'bedtimeMode': bedtimeMode.toJson(),
    'featureRules': featureRules.map((k, v) => MapEntry(k, v.toJson())),
  };

  factory AudioContextSettings.fromJson(Map<String, dynamic> json) {
    return AudioContextSettings(
      enabled: json['enabled'] as bool? ?? true,
      duckingLevel: (json['duckingLevel'] as num?)?.toDouble() ?? 0.3,
      duckDuringVoiceOutput: json['duckDuringVoiceOutput'] as bool? ?? true,
      duckDuringGameSfx: json['duckDuringGameSfx'] as bool? ?? true,
      pauseDuringVideo: json['pauseDuringVideo'] as bool? ?? true,
      pauseDuringVoiceInput: json['pauseDuringVoiceInput'] as bool? ?? true,
      bedtimeMode: json['bedtimeMode'] != null
          ? BedtimeModeSettings.fromJson(json['bedtimeMode'])
          : const BedtimeModeSettings(),
      featureRules:
          (json['featureRules'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, FeatureAudioRule.fromJson(v)),
          ) ??
          {},
    );
  }

  @override
  List<Object?> get props => [
    enabled,
    duckingLevel,
    duckDuringVoiceOutput,
    duckDuringGameSfx,
    pauseDuringVideo,
    pauseDuringVoiceInput,
    bedtimeMode,
    featureRules,
  ];
}

/// Bedtime mode settings for automatic volume reduction
class BedtimeModeSettings extends Equatable {
  /// Whether bedtime mode is enabled
  final bool enabled;

  /// Start time (hour:minute)
  final TimeOfDay startTime;

  /// End time (hour:minute)
  final TimeOfDay endTime;

  /// Volume multiplier during bedtime (0.0 - 1.0)
  final double volumeMultiplier;

  const BedtimeModeSettings({
    this.enabled = false,
    this.startTime = const TimeOfDay(hour: 22, minute: 0),
    this.endTime = const TimeOfDay(hour: 7, minute: 0),
    this.volumeMultiplier = 0.5,
  });

  /// Check if current time is within bedtime hours
  bool isActive(DateTime now) {
    if (!enabled) return false;

    final currentMinutes = now.hour * 60 + now.minute;
    final startMinutes = startTime.hour * 60 + startTime.minute;
    final endMinutes = endTime.hour * 60 + endTime.minute;

    if (startMinutes < endMinutes) {
      // Same day range (e.g., 14:00 - 18:00)
      return currentMinutes >= startMinutes && currentMinutes < endMinutes;
    } else {
      // Overnight range (e.g., 22:00 - 07:00)
      return currentMinutes >= startMinutes || currentMinutes < endMinutes;
    }
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'startHour': startTime.hour,
    'startMinute': startTime.minute,
    'endHour': endTime.hour,
    'endMinute': endTime.minute,
    'volumeMultiplier': volumeMultiplier,
  };

  factory BedtimeModeSettings.fromJson(Map<String, dynamic> json) {
    return BedtimeModeSettings(
      enabled: json['enabled'] as bool? ?? false,
      startTime: TimeOfDay(
        hour: json['startHour'] as int? ?? 22,
        minute: json['startMinute'] as int? ?? 0,
      ),
      endTime: TimeOfDay(
        hour: json['endHour'] as int? ?? 7,
        minute: json['endMinute'] as int? ?? 0,
      ),
      volumeMultiplier: (json['volumeMultiplier'] as num?)?.toDouble() ?? 0.5,
    );
  }

  @override
  List<Object?> get props => [enabled, startTime, endTime, volumeMultiplier];
}

/// Audio behavior for a specific feature
enum FeatureAudioBehavior {
  /// No special handling
  none,

  /// Duck music when feature is active
  duck,

  /// Pause music when feature is active
  pause,

  /// Coexist with music (no change)
  coexist,
}

/// Per-feature audio rule
class FeatureAudioRule extends Equatable {
  /// Feature identifier (e.g., 'quest', 'games', 'iptv', 'finance')
  final String featureId;

  /// Audio behavior when feature is active
  final FeatureAudioBehavior behavior;

  /// Custom ducking level for this feature (null = use global)
  final double? customDuckingLevel;

  /// Whether to auto-resume after feature loses focus
  final bool autoResume;

  const FeatureAudioRule({
    required this.featureId,
    this.behavior = FeatureAudioBehavior.duck,
    this.customDuckingLevel,
    this.autoResume = true,
  });

  Map<String, dynamic> toJson() => {
    'featureId': featureId,
    'behavior': behavior.index,
    'customDuckingLevel': customDuckingLevel,
    'autoResume': autoResume,
  };

  factory FeatureAudioRule.fromJson(Map<String, dynamic> json) {
    return FeatureAudioRule(
      featureId: json['featureId'] as String,
      behavior: FeatureAudioBehavior.values[json['behavior'] as int? ?? 1],
      customDuckingLevel: (json['customDuckingLevel'] as num?)?.toDouble(),
      autoResume: json['autoResume'] as bool? ?? true,
    );
  }

  @override
  List<Object?> get props => [
    featureId,
    behavior,
    customDuckingLevel,
    autoResume,
  ];
}
