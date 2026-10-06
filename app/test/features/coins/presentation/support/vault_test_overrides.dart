import 'package:feature_coin/feature_coin.dart';

/// Keeps NFC / vault-gated flows unlocked without touching biometrics.
class TestVaultSessionNotifier extends VaultSessionNotifier {
  @override
  VaultSessionState build() => const VaultUnlocked();

  @override
  Future<void> unlock() async {}
}
