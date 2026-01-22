import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'secure_store.dart';

/// Flutter Secure Storage implementation of SecureStore.
///
/// Uses platform-specific secure storage:
/// - Android: Custom secure ciphers backed by Android Keystore (v10+)
/// - iOS: Keychain Services
/// - Web: Encrypted localStorage (less secure, consider alternatives)
/// - macOS: Keychain Services
/// - Linux: libsecret
/// - Windows: Windows Credential Manager
class FlutterSecureStore implements SecureStore {
  FlutterSecureStore({FlutterSecureStorage? storage})
    : _storage = storage ?? _createSecureStorage();

  final FlutterSecureStorage _storage;

  /// Creates a FlutterSecureStorage with secure options
  ///
  /// Note: flutter_secure_storage v10+ uses custom cipher implementations
  /// instead of deprecated EncryptedSharedPreferences. Auto-migration
  /// is enabled by default (migrateOnAlgorithmChange: true).
  static FlutterSecureStorage _createSecureStorage() =>
      const FlutterSecureStorage(
        aOptions: AndroidOptions(
          // v10+: encryptedSharedPreferences removed, using new secure ciphers
          // Auto-migration from old storage happens automatically
          sharedPreferencesName: 'airo_secure_prefs',
          preferencesKeyPrefix: 'airo_',
        ),
        iOptions: IOSOptions(
          accessibility: KeychainAccessibility.first_unlock_this_device,
          accountName: 'airo_app',
        ),
        webOptions: WebOptions(
          dbName: 'airo_secure_storage',
          publicKey: 'airo_public_key',
        ),
        mOptions: MacOsOptions(
          accountName: 'airo_app',
          groupId: 'com.developerscoffee.airo',
        ),
        lOptions: LinuxOptions(
          // Linux uses libsecret
        ),
      );

  @override
  Future<String?> read({required String key}) async {
    try {
      return await _storage.read(key: key);
    } catch (e) {
      // Log error but don't crash - return null for missing/unreadable keys
      return null;
    }
  }

  @override
  Future<void> write({required String key, required String value}) async {
    await _storage.write(key: key, value: value);
  }

  @override
  Future<void> delete({required String key}) async {
    await _storage.delete(key: key);
  }

  @override
  Future<void> deleteAll() async {
    await _storage.deleteAll();
  }

  @override
  Future<bool> containsKey({required String key}) async {
    try {
      return await _storage.containsKey(key: key);
    } catch (e) {
      return false;
    }
  }
}

/// Factory for creating SecureStore instances based on environment.
class SecureStoreFactory {
  /// Creates a SecureStore for production use.
  ///
  /// Uses platform-specific secure storage (Keystore/Keychain).
  static SecureStore createSecure() => FlutterSecureStore();

  /// Creates a SecureStore for testing.
  ///
  /// Uses in-memory storage - NOT for production!
  static SecureStore createForTesting() => InMemorySecureStore();

  /// Creates a SecureStore based on debug mode.
  ///
  /// Uses secure storage in release mode, in-memory for debug.
  static SecureStore create({bool isDebug = false}) =>
      isDebug ? createForTesting() : createSecure();
}
