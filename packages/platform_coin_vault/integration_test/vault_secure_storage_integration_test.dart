// packages/platform_coin_vault/integration_test/vault_secure_storage_integration_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:platform_coin_vault/src/crypto/vault_secure_storage.dart';

/// Real-device/emulator smoke test for [VaultSecureStorage] — the
/// `flutter_secure_storage` platform-channel wrapper that unit tests cannot
/// exercise (there is no in-memory fake for the real Keystore/Keychain
/// channel). Run with:
///
/// ```sh
/// flutter test integration_test/vault_secure_storage_integration_test.dart -d <device-id>
/// ```
///
/// This test verifies the write/read/delete roundtrip works against the
/// real platform channel. It does NOT verify that the biometric prompt
/// actually appears — that requires interactive human confirmation and is
/// outside what an automated integration test can assert. When running
/// manually, confirm a biometric/device-credential prompt appears before
/// the first read/write succeeds; if it does not, `enforceBiometrics` in
/// `VaultSecureStorage`'s `AndroidOptions.biometric(...)` has regressed.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('write, read, and delete roundtrip against the real secure storage channel', (
    tester,
  ) async {
    final storage = VaultSecureStorage();
    const key = 'integration_test_key';
    const value = 'integration_test_value';

    await storage.delete(key);

    final writeResult = await storage.write(key, value);
    expect(writeResult.isSuccess, isTrue);

    final readResult = await storage.read(key);
    expect(readResult.value, value);

    final containsResult = await storage.containsKey(key);
    expect(containsResult.value, isTrue);

    final deleteResult = await storage.delete(key);
    expect(deleteResult.isSuccess, isTrue);

    final afterDelete = await storage.read(key);
    expect(afterDelete.value, isNull);
  });
}
