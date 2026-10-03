import 'package:feature_coin/feature_coin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/auth_service.dart';

/// Session rules for NFC / deep-link quick capture entry.
///
/// Navigation may reach the capture route when auth preconditions pass; the
/// capture screen then prompts for the same vault biometric unlock used for
/// records ([vaultSessionProvider] → [VaultUnlocked]). A custom scheme, cold
/// start, or launcher entry is not authentication.
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

  /// Whether the app may route to the quick-capture screen (login only).
  static Future<bool> canRouteToQuickCaptureSuperApp({
    WidgetRef? ref,
    BuildContext? context,
  }) async {
    await AuthService.instance.initialize();
    return AuthService.instance.isLoggedIn;
  }

  /// Coins standalone has no login surface; routing does not require vault
  /// unlock upfront (unlock is prompted on the capture screen).
  static bool canRouteToQuickCaptureCoinsShell({
    WidgetRef? ref,
    BuildContext? context,
  }) {
    return true;
  }
}
