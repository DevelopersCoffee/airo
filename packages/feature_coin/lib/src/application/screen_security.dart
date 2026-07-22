import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screen_protector/screen_protector.dart';

/// Prevents screenshots and recents thumbnails while vault routes are visible.
///
/// Best-effort by design: plugin failure must never block vault usage.
class VaultScreenSecurity {
  VaultScreenSecurity({
    this.enableProtection = ScreenProtector.protectDataLeakageOn,
    this.disableProtection = ScreenProtector.protectDataLeakageOff,
  });

  final Future<void> Function() enableProtection;
  final Future<void> Function() disableProtection;

  var _activeProtectors = 0;

  Future<void> protect() async {
    _activeProtectors++;
    if (_activeProtectors > 1) return;
    try {
      await enableProtection();
    } catch (_) {
      // Native screen-protection failures must not block access to the vault.
    }
  }

  Future<void> unprotect() async {
    if (_activeProtectors == 0) return;
    _activeProtectors--;
    if (_activeProtectors > 0) return;
    try {
      await disableProtection();
    } catch (_) {
      // See protect().
    }
  }
}

final screenSecurityProvider = Provider<VaultScreenSecurity>(
  (ref) => VaultScreenSecurity(),
);
