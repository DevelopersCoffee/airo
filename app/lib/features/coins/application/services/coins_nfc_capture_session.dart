import '../../../../core/auth/auth_service.dart';

import 'coins_nfc_capture_platform.dart';

/// Gates NFC / deep-link quick capture on an active local session.
///
/// The super-app treats a persisted login as the unlocked session. The coins
/// standalone shell has no login surface; it requires a trusted in-process
/// entry (launcher / resumed app), not a capture-only cold start.
class CoinsNfcCaptureSession {
  CoinsNfcCaptureSession._();

  static Future<bool> canOpenQuickCaptureSuperApp() async {
    await AuthService.instance.initialize();
    return AuthService.instance.isLoggedIn;
  }

  static Future<bool> canOpenQuickCaptureCoinsShell() async {
    return CoinsNfcCapturePlatform.isTrustedLocalSession();
  }
}
