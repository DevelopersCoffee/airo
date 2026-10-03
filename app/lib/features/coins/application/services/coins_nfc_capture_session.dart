import 'package:feature_coin/feature_coin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/auth_service.dart';

/// Session helpers for NFC / deep-link quick capture.
///
/// Routing may open the capture screen after login (super-app only). Biometric
/// unlock is prompted on that screen. A custom scheme, cold start, or launcher
/// entry is not authentication.
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

  static Future<bool> passesSuperAppLoginGate() async {
    await AuthService.instance.initialize();
    return AuthService.instance.isLoggedIn;
  }
}
