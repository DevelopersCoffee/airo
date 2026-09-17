/// Preset application tuning profiles for Airo Haptics.
enum AiroHapticProfile {
  /// Default balanced haptic tuning.
  defaultProfile,

  /// Minimal subtle feedback (ideal for quiet environments).
  minimal,

  /// High-energy tactile feedback for gaming & action controls.
  gaming,

  /// High-clarity tactile feedback with boosted intensity for accessibility.
  accessibility,

  /// Optimized for TV D-Pad & remote control navigation.
  tv,

  /// Smooth feedback tuned for scrubbing & media player controls.
  media,

  /// Subtle voice assistant & prompt feedback.
  assistant;

  /// Human-readable label for debugging and UI inspectors.
  String get label => switch (this) {
        AiroHapticProfile.defaultProfile => 'Default',
        AiroHapticProfile.minimal => 'Minimal',
        AiroHapticProfile.gaming => 'Gaming',
        AiroHapticProfile.accessibility => 'Accessibility',
        AiroHapticProfile.tv => 'TV Navigation',
        AiroHapticProfile.media => 'Media Control',
        AiroHapticProfile.assistant => 'Voice Assistant',
      };

  /// Recommended master intensity multiplier for this profile.
  double get intensityScale => switch (this) {
        AiroHapticProfile.defaultProfile => 1.0,
        AiroHapticProfile.minimal => 0.4,
        AiroHapticProfile.gaming => 1.2,
        AiroHapticProfile.accessibility => 1.4,
        AiroHapticProfile.tv => 0.8,
        AiroHapticProfile.media => 0.6,
        AiroHapticProfile.assistant => 0.5,
      };

  /// Minimum throttle window between consecutive events.
  Duration get minThrottleWindow => switch (this) {
        AiroHapticProfile.defaultProfile => const Duration(milliseconds: 25),
        AiroHapticProfile.minimal => const Duration(milliseconds: 50),
        AiroHapticProfile.gaming => const Duration(milliseconds: 10),
        AiroHapticProfile.accessibility => const Duration(milliseconds: 30),
        AiroHapticProfile.tv => const Duration(milliseconds: 40),
        AiroHapticProfile.media => const Duration(milliseconds: 35),
        AiroHapticProfile.assistant => const Duration(milliseconds: 45),
      };
}
