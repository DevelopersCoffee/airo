import 'package:core_data/core_data.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_coin_vault/src/crypto/vault_key_manager.dart';

void main() {
  late InMemorySecureStorage secureStorage;

  setUp(() {
    secureStorage = InMemorySecureStorage();
  });

  group('VaultKeyManager', () {
    test('getDatabaseKey generates and persists a 32-byte key on first call', () async {
      final manager = VaultKeyManager.forTesting(
        secureStorage: secureStorage,
        authenticate: () async => true,
      );

      final result = await manager.getDatabaseKey();

      expect(result.isSuccess, isTrue);
      expect(result.value, hasLength(32));
    });

    test('getDatabaseKey returns the same key on repeated calls', () async {
      final manager = VaultKeyManager.forTesting(
        secureStorage: secureStorage,
        authenticate: () async => true,
      );

      final first = await manager.getDatabaseKey();
      final second = await manager.getDatabaseKey();

      expect(second.value, equals(first.value));
    });

    test('getDatabaseKey fails when biometric authentication is denied', () async {
      final manager = VaultKeyManager.forTesting(
        secureStorage: secureStorage,
        authenticate: () async => false,
      );

      final result = await manager.getDatabaseKey();

      expect(result.isFailure, isTrue);
      expect(result.failure, isA<AuthFailure>());
    });

    test('rotateKey generates a different key and persists it', () async {
      final manager = VaultKeyManager.forTesting(
        secureStorage: secureStorage,
        authenticate: () async => true,
      );

      final original = await manager.getDatabaseKey();
      final rotated = await manager.rotateKey();
      final afterRotate = await manager.getDatabaseKey();

      expect(rotated.isSuccess, isTrue);
      expect(afterRotate.value, isNot(equals(original.value)));
    });

    test('clearKeys removes the stored key', () async {
      final manager = VaultKeyManager.forTesting(
        secureStorage: secureStorage,
        authenticate: () async => true,
      );

      await manager.getDatabaseKey();
      await manager.clearKeys();
      final containsKey = await secureStorage.containsKey('airo_coin_wrapped_dek');

      expect(containsKey.value, isFalse);
    });

    test('isEncryptionAvailable reports false when biometrics are unavailable, blocking vault creation', () async {
      final manager = VaultKeyManager.forTesting(
        secureStorage: secureStorage,
        authenticate: () async => false,
      );

      final result = await manager.getDatabaseKey();

      expect(result.isFailure, isTrue);
      expect(result.failure, isA<AuthFailure>());
    });

    test('getDatabaseKey fails closed when local_auth throws (e.g. no biometrics enrolled)', () async {
      final manager = VaultKeyManager.forTesting(
        secureStorage: secureStorage,
        authenticate: () async => throw Exception('platform unavailable'),
      );

      final result = await manager.getDatabaseKey();

      expect(result.isFailure, isTrue);
      expect(result.failure, isA<AuthFailure>());
    });

    test('rotateKey fails closed when local_auth throws (e.g. no biometrics enrolled)', () async {
      final manager = VaultKeyManager.forTesting(
        secureStorage: secureStorage,
        authenticate: () async => throw Exception('platform unavailable'),
      );

      final result = await manager.rotateKey();

      expect(result.isFailure, isTrue);
      expect(result.failure, isA<AuthFailure>());
    });

    test('isEncryptionAvailable uses the injected isAvailable seam when provided', () async {
      final manager = VaultKeyManager.forTesting(
        secureStorage: secureStorage,
        authenticate: () async => true,
        isAvailable: () async => false,
      );

      final available = await manager.isEncryptionAvailable();
      final keyResult = await manager.getDatabaseKey();

      expect(available, isFalse);
      expect(keyResult.isSuccess, isTrue);
    });
  });
}
