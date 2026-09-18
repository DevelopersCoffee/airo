import '../models/haptic_intent.dart';

/// Prevents rapid duplicate haptic triggers within a specified time window.
class AiroHapticThrottle {
  AiroHapticThrottle();

  final Map<String, DateTime> _lastTriggered = {};

  /// Checks if a trigger with [key] and [priority] should be allowed at [now].
  /// Critical priority triggers bypass throttling.
  bool shouldAllow({
    required String key,
    required Duration minWindow,
    required AiroHapticPriority priority,
    DateTime? now,
  }) {
    if (priority == AiroHapticPriority.critical) {
      _lastTriggered[key] = now ?? DateTime.now();
      return true;
    }

    final current = now ?? DateTime.now();
    final previous = _lastTriggered[key];

    if (previous == null || current.difference(previous) >= minWindow) {
      _lastTriggered[key] = current;
      return true;
    }

    return false;
  }

  /// Clears throttle records.
  void clear() {
    _lastTriggered.clear();
  }
}
