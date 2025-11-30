import 'package:core_data/core_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EncryptionService', () {
    late InMemorySecureStore secureStore;
    late EncryptionService encryptionService;

    setUp(() {
      secureStore = InMemorySecureStore();
      encryptionService = EncryptionService(secureStore: secureStore);
    });

    test('getDatabaseKey generates new key on first call', () async {
      final key = await encryptionService.getDatabaseKey();

      expect(key, isNotEmpty);
      expect(key.length, greaterThan(20)); // Base64 encoded key
    });

    test('getDatabaseKey returns same key on subsequent calls', () async {
      final key1 = await encryptionService.getDatabaseKey();
      final key2 = await encryptionService.getDatabaseKey();

      expect(key1, equals(key2));
    });

    test('getDatabaseKey retrieves stored key', () async {
      // Store a key manually
      await secureStore.write(
        key: SecureStoreKeys.databaseKey,
        value: 'my_stored_key',
      );

      final key = await encryptionService.getDatabaseKey();

      expect(key, 'my_stored_key');
    });

    test('rotateDatabaseKey generates new key', () async {
      final originalKey = await encryptionService.getDatabaseKey();
      final newKey = await encryptionService.rotateDatabaseKey();

      expect(newKey, isNot(equals(originalKey)));
    });

    test('rotateDatabaseKey updates stored key', () async {
      await encryptionService.getDatabaseKey();
      final rotatedKey = await encryptionService.rotateDatabaseKey();
      final retrievedKey = await encryptionService.getDatabaseKey();

      expect(retrievedKey, equals(rotatedKey));
    });

    test('hasDatabaseKey returns false when no key exists', () async {
      final hasKey = await encryptionService.hasDatabaseKey();

      expect(hasKey, isFalse);
    });

    test('hasDatabaseKey returns true after key creation', () async {
      await encryptionService.getDatabaseKey();
      final hasKey = await encryptionService.hasDatabaseKey();

      expect(hasKey, isTrue);
    });

    test('clearCache forces re-read from storage', () async {
      await encryptionService.getDatabaseKey();

      // Manually update storage
      await secureStore.write(
        key: SecureStoreKeys.databaseKey,
        value: 'updated_key',
      );

      // Clear cache and get key again
      encryptionService.clearCache();
      final key = await encryptionService.getDatabaseKey();

      expect(key, 'updated_key');
    });

    test('deleteAllKeys removes all encryption keys', () async {
      await encryptionService.getDatabaseKey();
      await encryptionService.deleteAllKeys();

      final hasKey = await encryptionService.hasDatabaseKey();
      expect(hasKey, isFalse);
    });
  });

  group('EncryptionConfig', () {
    test('production config has encryption enabled', () {
      const config = EncryptionConfig.production;

      expect(config.enableDatabaseEncryption, isTrue);
      expect(config.enableAtRestEncryption, isTrue);
      expect(config.keyRotationDays, 90);
    });

    test('development config has encryption disabled', () {
      const config = EncryptionConfig.development;

      expect(config.enableDatabaseEncryption, isFalse);
      expect(config.enableAtRestEncryption, isFalse);
      expect(config.keyRotationDays, 0);
    });

    test('custom config can be created', () {
      const config = EncryptionConfig(
        enableDatabaseEncryption: true,
        enableAtRestEncryption: false,
        keyRotationDays: 30,
      );

      expect(config.enableDatabaseEncryption, isTrue);
      expect(config.enableAtRestEncryption, isFalse);
      expect(config.keyRotationDays, 30);
    });
  });
}

