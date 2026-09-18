/// Semantic haptic feedback types supported by Airo Haptics.
enum AiroHapticFeedbackType {
  // Layer 1 - Core Semantic
  success,
  warning,
  error,
  selection,
  impact,
  confirm,
  reject,
  delete,
  toggleOn,
  toggleOff,
  longPress,
  dragStart,
  dragEnd,
  refresh,
  notification,
  focus,
  navigation,
  press,
  completion,
  failure,
  boundary;

  String get nameLabel => name;
}

/// Physical intensity shortcuts for impact feedback.
enum AiroHapticImpact {
  light,
  medium,
  heavy,
  soft,
  rigid;

  /// Default relative intensity value (0.0 to 1.0).
  double get defaultIntensity => switch (this) {
        AiroHapticImpact.light => 0.3,
        AiroHapticImpact.medium => 0.6,
        AiroHapticImpact.heavy => 1.0,
        AiroHapticImpact.soft => 0.4,
        AiroHapticImpact.rigid => 0.8,
      };

  /// Default relative sharpness value (0.0 to 1.0).
  double get defaultSharpness => switch (this) {
        AiroHapticImpact.light => 0.5,
        AiroHapticImpact.medium => 0.5,
        AiroHapticImpact.heavy => 0.7,
        AiroHapticImpact.soft => 0.2,
        AiroHapticImpact.rigid => 0.9,
      };
}

/// Priority level for haptic feedback execution.
enum AiroHapticPriority implements Comparable<AiroHapticPriority> {
  decorative(0),
  low(0),
  normal(1),
  important(2),
  high(2),
  critical(3);

  const AiroHapticPriority(this.value);
  final int value;

  @override
  int compareTo(AiroHapticPriority other) => value.compareTo(other.value);

  bool operator >=(AiroHapticPriority other) => value >= other.value;
  bool operator >(AiroHapticPriority other) => value > other.value;
  bool operator <=(AiroHapticPriority other) => value <= other.value;
  bool operator <(AiroHapticPriority other) => value < other.value;
}
