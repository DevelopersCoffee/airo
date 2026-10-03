import 'package:feature_coin/feature_coin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/auth_service.dart';

/// Gates NFC / deep-link quick capture on an unlocked vault session.
///
/// Quick capture uses the same biometric-gated [vaultSessionProvider] as the
/// secure vault. A custom scheme, cold start, or launcher entry does not
/// satisfy this gate — only [VaultUnlocked] after successful local auth.
class CoinsNfcCaptureSession {
  CoinsNfcCaptureSession._();

  static bool isVaultUnlocked(WidgetRef ref) {
    return ref.read(vaultSessionProvider) is VaultUnlocked;
  }

  static bool isVaultUnlockedFromContext(BuildContext context) {
    try {
      final container = ProviderScope.containerOf(context, listen: false);
      return container.read(vaultSessionProvider) is VaultUnlocked;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> canOpenQuickCaptureSuperApp({
    WidgetRef? ref,
    BuildContext? context,
  }) async {
    await AuthService.instance.initialize();
    if (!AuthService.instance.isLoggedIn) {
      return false;
    }
    if (ref != null) {
      return isVaultUnlocked(ref);
    }
    if (context != null) {
      return isVaultUnlockedFromContext(context);
    }
    return false;
  }

  static bool canOpenQuickCaptureCoinsShell({
    WidgetRef? ref,
    BuildContext? context,
  }) {
    if (ref != null) {
      return isVaultUnlocked(ref);
    }
    if (context != null) {
      return isVaultUnlockedFromContext(context);
    }
    return false;
  }
}
