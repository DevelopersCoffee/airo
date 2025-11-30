import 'dart:convert';
import 'dart:math';

import 'key_value_store.dart';

/// Abstract interface for secure key-value storage.
///
/// This interface should be implemented using platform-specific secure storage:
/// - Android: Android Keystore + EncryptedSharedPreferences
/// - iOS: iOS Keychain
/// - Web: Encrypted localStorage with session-derived keys
abstract class SecureStore {
  /// Reads a secure value by key
  Future<String?> read({required String key});

  /// Writes a secure value
  Future<void> write({required String key, required String value});

  /// Deletes a secure value
  Future<void> delete({required String key});

  /// Deletes all secure values
  Future<void> deleteAll();

  /// Checks if a key exists
  Future<bool> containsKey({required String key});
}

/// Keys used for secure storage
abstract final class SecureStoreKeys {
  /// Database encryption key
  static const String databaseKey = 'airo_db_encryption_key';

  /// User session token
  static const String sessionToken = 'airo_session_token';

  /// API keys (encrypted)
  static const String apiKeys = 'airo_api_keys';

  /// Biometric authentication enabled
  static const String biometricEnabled = 'airo_biometric_enabled';

  /// PIN code hash (for fallback auth)
  static const String pinCodeHash = 'airo_pin_hash';
}

/// Key derivation utilities for encryption
abstract final class KeyDerivation {
  /// Generates a random encryption key
  static String generateKey({int length = 32}) {
    final random = Random.secure();
    final bytes = List<int>.generate(length, (_) => random.nextInt(256));
    return base64Url.encode(bytes);
  }

  /// Generates a key from a passphrase using simple PBKDF-like approach
  /// Note: In production, use a proper PBKDF2 implementation
  static String deriveFromPassphrase(String passphrase, {String? salt}) {
    final effectiveSalt = salt ?? 'airo_default_salt_v1';
    final combined = '$passphrase:$effectiveSalt';

    // Simple hash-based key derivation (use crypto package in production)
    var hash = 0;
    for (var i = 0; i < combined.length; i++) {
      hash = ((hash << 5) - hash) + combined.codeUnitAt(i);
      hash = hash & 0xFFFFFFFF;
    }

    // Extend to proper key length
    final buffer = StringBuffer();
    for (var i = 0; i < 32; i++) {
      hash = ((hash << 5) - hash) + i;
      hash = hash & 0xFFFFFFFF;
      buffer.write(String.fromCharCode((hash.abs() % 94) + 33));
    }

    return base64Url.encode(buffer.toString().codeUnits);
  }
}

/// In-memory secure store for testing.
///
/// DO NOT use in production - values are not encrypted.
class InMemorySecureStore implements SecureStore {
  final Map<String, String> _store = {};

  @override
  Future<String?> read({required String key}) async => _store[key];

  @override
  Future<void> write({required String key, required String value}) async {
    _store[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    _store.remove(key);
  }

  @override
  Future<void> deleteAll() async {
    _store.clear();
  }

  @override
  Future<bool> containsKey({required String key}) async =>
      _store.containsKey(key);
}

/// Adapter to use SecureStore as KeyValueStore
class SecureKeyValueStoreAdapter implements KeyValueStore {
  SecureKeyValueStoreAdapter(this._secureStore);

  final SecureStore _secureStore;

  @override
  Future<String?> getString(String key) => _secureStore.read(key: key);

  @override
  Future<bool> setString(String key, String value) async {
    await _secureStore.write(key: key, value: value);
    return true;
  }

  @override
  Future<int?> getInt(String key) async {
    final value = await _secureStore.read(key: key);
    return value != null ? int.tryParse(value) : null;
  }

  @override
  Future<bool> setInt(String key, int value) async {
    await _secureStore.write(key: key, value: value.toString());
    return true;
  }

  @override
  Future<double?> getDouble(String key) async {
    final value = await _secureStore.read(key: key);
    return value != null ? double.tryParse(value) : null;
  }

  @override
  Future<bool> setDouble(String key, double value) async {
    await _secureStore.write(key: key, value: value.toString());
    return true;
  }

  @override
  Future<bool?> getBool(String key) async {
    final value = await _secureStore.read(key: key);
    return value != null ? value == 'true' : null;
  }

  @override
  Future<bool> setBool(String key, {required bool value}) async {
    await _secureStore.write(key: key, value: value.toString());
    return true;
  }

  @override
  Future<List<String>?> getStringList(String key) async {
    final value = await _secureStore.read(key: key);
    if (value == null) return null;
    return (jsonDecode(value) as List).cast<String>();
  }

  @override
  Future<bool> setStringList(String key, List<String> value) async {
    await _secureStore.write(key: key, value: jsonEncode(value));
    return true;
  }

  @override
  Future<bool> containsKey(String key) => _secureStore.containsKey(key: key);

  @override
  Future<bool> remove(String key) async {
    await _secureStore.delete(key: key);
    return true;
  }

  @override
  Future<bool> clear() async {
    await _secureStore.deleteAll();
    return true;
  }
}

