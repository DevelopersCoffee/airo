import 'package:core_data/core_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InMemorySecureStore', () {
    late InMemorySecureStore store;

    setUp(() {
      store = InMemorySecureStore();
    });

    test('write and read string value', () async {
      await store.write(key: 'test_key', value: 'test_value');
      final result = await store.read(key: 'test_key');
      expect(result, 'test_value');
    });

    test('read returns null for non-existent key', () async {
      final result = await store.read(key: 'non_existent');
      expect(result, isNull);
    });

    test('delete removes value', () async {
      await store.write(key: 'test_key', value: 'test_value');
      await store.delete(key: 'test_key');
      final result = await store.read(key: 'test_key');
      expect(result, isNull);
    });

    test('deleteAll clears all values', () async {
      await store.write(key: 'key1', value: 'value1');
      await store.write(key: 'key2', value: 'value2');
      await store.deleteAll();
      expect(await store.read(key: 'key1'), isNull);
      expect(await store.read(key: 'key2'), isNull);
    });

    test('containsKey returns true for existing key', () async {
      await store.write(key: 'test_key', value: 'test_value');
      final result = await store.containsKey(key: 'test_key');
      expect(result, isTrue);
    });

    test('containsKey returns false for non-existent key', () async {
      final result = await store.containsKey(key: 'non_existent');
      expect(result, isFalse);
    });
  });

  group('KeyDerivation', () {
    test('generateKey creates random key of expected length', () {
      final key1 = KeyDerivation.generateKey();
      final key2 = KeyDerivation.generateKey();

      expect(key1, isNotEmpty);
      expect(key2, isNotEmpty);
      expect(key1, isNot(equals(key2))); // Should be random
    });

    test('generateKey respects custom length', () {
      final key16 = KeyDerivation.generateKey(length: 16);
      final key64 = KeyDerivation.generateKey(length: 64);

      // Base64 encoded lengths
      expect(key16.length, greaterThan(16));
      expect(key64.length, greaterThan(key16.length));
    });

    test('deriveFromPassphrase is deterministic', () {
      final key1 = KeyDerivation.deriveFromPassphrase('password123');
      final key2 = KeyDerivation.deriveFromPassphrase('password123');

      expect(key1, equals(key2));
    });

    test('deriveFromPassphrase differs with different passphrases', () {
      final key1 = KeyDerivation.deriveFromPassphrase('password1');
      final key2 = KeyDerivation.deriveFromPassphrase('password2');

      expect(key1, isNot(equals(key2)));
    });

    test('deriveFromPassphrase differs with different salts', () {
      final key1 =
          KeyDerivation.deriveFromPassphrase('password', salt: 'salt1');
      final key2 =
          KeyDerivation.deriveFromPassphrase('password', salt: 'salt2');

      expect(key1, isNot(equals(key2)));
    });
  });

  group('SecureKeyValueStoreAdapter', () {
    late InMemorySecureStore secureStore;
    late SecureKeyValueStoreAdapter adapter;

    setUp(() {
      secureStore = InMemorySecureStore();
      adapter = SecureKeyValueStoreAdapter(secureStore);
    });

    test('setString and getString', () async {
      await adapter.setString('key', 'value');
      final result = await adapter.getString('key');
      expect(result, 'value');
    });

    test('setInt and getInt', () async {
      await adapter.setInt('key', 42);
      final result = await adapter.getInt('key');
      expect(result, 42);
    });

    test('setDouble and getDouble', () async {
      await adapter.setDouble('key', 3.14);
      final result = await adapter.getDouble('key');
      expect(result, 3.14);
    });

    test('setBool and getBool', () async {
      await adapter.setBool('key', value: true);
      final result = await adapter.getBool('key');
      expect(result, isTrue);
    });

    test('setStringList and getStringList', () async {
      await adapter.setStringList('key', ['a', 'b', 'c']);
      final result = await adapter.getStringList('key');
      expect(result, ['a', 'b', 'c']);
    });

    test('remove deletes key', () async {
      await adapter.setString('key', 'value');
      await adapter.remove('key');
      final result = await adapter.getString('key');
      expect(result, isNull);
    });

    test('clear removes all keys', () async {
      await adapter.setString('key1', 'value1');
      await adapter.setString('key2', 'value2');
      await adapter.clear();
      expect(await adapter.getString('key1'), isNull);
      expect(await adapter.getString('key2'), isNull);
    });
  });
}

