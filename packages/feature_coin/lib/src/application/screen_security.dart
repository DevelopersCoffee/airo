import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screen_protector/screen_protector.dart';

class VaultScreenSecurity {
  const VaultScreenSecurity({
    this.enableProtection = ScreenProtector.protectDataLeakageOn,
    this.disableProtection = ScreenProtector.protectDataLeakageOff,
  });

  final Future<void> Function() enableProtection;
  final Future<void> Function() disableProtection;

  Future<void> protect() async {
    try {
      await enableProtection();
    } catch (_) {
      // Native screen-protection failures must not block access to the vault.
    }
  }

  Future<void> unprotect() async {
    try {
      await disableProtection();
    } catch (_) {
      // See protect().
    }
  }
}

final screenSecurityProvider = Provider<VaultScreenSecurity>(
  (ref) => const VaultScreenSecurity(),
);
