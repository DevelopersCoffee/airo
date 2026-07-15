/// Stub implementation of wakelock_plus for lean TV builds.
library;

class WakelockPlus {
  static bool _enabled = false;

  static Future<void> enable() => toggle(enable: true);

  static Future<void> disable() => toggle(enable: false);

  static Future<void> toggle({required bool enable}) async {
    _enabled = enable;
  }

  static Future<bool> get enabled async => _enabled;
}
