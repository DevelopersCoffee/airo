import 'package:screen_protector/screen_protector.dart';

/// Prevents screenshots and recents thumbnails while vault routes are visible.
///
/// Best-effort by design: plugin failure must never block vault usage.
abstract final class ScreenSecurity {
  static Future<void> protect() async {
    try {
      await ScreenProtector.protectDataLeakageOn();
    } catch (_) {
      // Plugin unavailable in tests or on unsupported platforms.
    }
  }

  static Future<void> unprotect() async {
    try {
      await ScreenProtector.protectDataLeakageOff();
    } catch (_) {
      // See protect().
    }
  }
}
