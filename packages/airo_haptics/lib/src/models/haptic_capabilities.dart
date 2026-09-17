import 'package:equatable/equatable.dart';

/// Supported target platforms for Airo Haptics.
enum AiroHapticDevicePlatform {
  android,
  ios,
  macOS,
  windows,
  linux,
  web,
  fuchsia,
  unknown;

  /// Human-readable label for debugging and diagnostics.
  String get nameLabel => switch (this) {
        AiroHapticDevicePlatform.android => 'Android',
        AiroHapticDevicePlatform.ios => 'iOS',
        AiroHapticDevicePlatform.macOS => 'macOS',
        AiroHapticDevicePlatform.windows => 'Windows',
        AiroHapticDevicePlatform.linux => 'Linux',
        AiroHapticDevicePlatform.web => 'Web',
        AiroHapticDevicePlatform.fuchsia => 'Fuchsia',
        AiroHapticDevicePlatform.unknown => 'Unknown',
      };
}

/// Represents the physical and software haptic capabilities of the device/platform.
class AiroHapticCapabilities extends Equatable {
  const AiroHapticCapabilities({
    required this.supported,
    required this.basic,
    required this.advanced,
    required this.customPatterns,
    required this.continuous,
    required this.variableIntensity,
    required this.variableSharpness,
    required this.platform,
    this.backend,
  });

  /// No-op capabilities default for unsupported platforms or devices without actuators.
  const AiroHapticCapabilities.unsupported({
    this.platform = AiroHapticDevicePlatform.unknown,
    this.backend = 'no_op',
  })  : supported = false,
        basic = false,
        advanced = false,
        customPatterns = false,
        continuous = false,
        variableIntensity = false,
        variableSharpness = false;

  /// Full capability profile for testing or high-end haptic devices.
  const AiroHapticCapabilities.full({
    required this.platform,
    this.backend = 'native_advanced',
  })  : supported = true,
        basic = true,
        advanced = true,
        customPatterns = true,
        continuous = true,
        variableIntensity = true,
        variableSharpness = true;

  /// Basic capability profile (e.g., standard vibrator or Web Vibration API).
  const AiroHapticCapabilities.basicOnly({
    required this.platform,
    this.backend = 'native_vibrator',
  })  : supported = true,
        basic = true,
        advanced = false,
        customPatterns = false,
        continuous = false,
        variableIntensity = false,
        variableSharpness = false;

  factory AiroHapticCapabilities.fromJson(Map<String, dynamic> json) {
    return AiroHapticCapabilities(
      supported: json['supported'] as bool? ?? false,
      basic: json['basic'] as bool? ?? false,
      advanced: json['advanced'] as bool? ?? false,
      customPatterns: json['customPatterns'] as bool? ?? false,
      continuous: json['continuous'] as bool? ?? false,
      variableIntensity: json['variableIntensity'] as bool? ?? false,
      variableSharpness: json['variableSharpness'] as bool? ?? false,
      platform: AiroHapticDevicePlatform.values.byName(
        json['platform'] as String? ?? 'unknown',
      ),
      backend: json['backend'] as String?,
    );
  }

  /// Whether the hardware and OS support any form of haptic feedback.
  final bool supported;

  /// Whether basic semantic feedback (e.g. click, selection) is available.
  final bool basic;

  /// Whether advanced composition (e.g. Core Haptics / Android Composition) is supported.
  final bool advanced;

  /// Whether custom transient/continuous pattern playback is supported.
  final bool customPatterns;

  /// Whether continuous sustained haptic playback is supported.
  final bool continuous;

  /// Whether variable intensity scaling (0.0 to 1.0) is supported by the actuator.
  final bool variableIntensity;

  /// Whether variable sharpness/frequency tuning is supported.
  final bool variableSharpness;

  /// Target platform operating environment.
  final AiroHapticDevicePlatform platform;

  /// Internal name of the active native rendering backend.
  final String? backend;

  Map<String, dynamic> toJson() => {
        'supported': supported,
        'basic': basic,
        'advanced': advanced,
        'customPatterns': customPatterns,
        'continuous': continuous,
        'variableIntensity': variableIntensity,
        'variableSharpness': variableSharpness,
        'platform': platform.name,
        'backend': backend,
      };

  @override
  List<Object?> get props => [
        supported,
        basic,
        advanced,
        customPatterns,
        continuous,
        variableIntensity,
        variableSharpness,
        platform,
        backend,
      ];
}
