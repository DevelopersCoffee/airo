import '../storage/secure_store.dart';

/// Service for managing database encryption keys and encrypted storage.
///
/// This service handles:
/// - Key generation and storage
/// - Key retrieval for database initialization
/// - Key rotation (for security updates)
class EncryptionService {
  EncryptionService({required SecureStore secureStore})
      : _secureStore = secureStore;

  final SecureStore _secureStore;
  String? _cachedKey;

  /// Gets or creates the database encryption key.
  ///
  /// The key is stored in secure storage and cached in memory.
  Future<String> getDatabaseKey() async {
    // Check memory cache first
    if (_cachedKey != null) {
      return _cachedKey!;
    }

    // Try to read from secure storage
    final storedKey =
        await _secureStore.read(key: SecureStoreKeys.databaseKey);
    if (storedKey != null) {
      _cachedKey = storedKey;
      return storedKey;
    }

    // Generate new key if none exists
    final newKey = KeyDerivation.generateKey();
    await _secureStore.write(
      key: SecureStoreKeys.databaseKey,
      value: newKey,
    );
    _cachedKey = newKey;
    return newKey;
  }

  /// Rotates the database key.
  ///
  /// This should be called during security updates or if key compromise
  /// is suspected. Note: Existing databases will need to be re-encrypted.
  Future<String> rotateDatabaseKey() async {
    final newKey = KeyDerivation.generateKey();
    await _secureStore.write(
      key: SecureStoreKeys.databaseKey,
      value: newKey,
    );
    _cachedKey = newKey;
    return newKey;
  }

  /// Checks if a database key exists.
  Future<bool> hasDatabaseKey() async =>
      _secureStore.containsKey(key: SecureStoreKeys.databaseKey);

  /// Clears the cached key (e.g., on logout).
  void clearCache() {
    _cachedKey = null;
  }

  /// Deletes all encryption keys.
  ///
  /// Warning: This will make encrypted data unrecoverable!
  Future<void> deleteAllKeys() async {
    await _secureStore.deleteAll();
    _cachedKey = null;
  }
}

/// Configuration for encryption settings.
class EncryptionConfig {
  const EncryptionConfig({
    this.enableDatabaseEncryption = true,
    this.enableAtRestEncryption = true,
    this.keyRotationDays = 90,
  });

  /// Whether to encrypt the SQLite database using SQLCipher.
  final bool enableDatabaseEncryption;

  /// Whether to encrypt data at rest in storage.
  final bool enableAtRestEncryption;

  /// Number of days between automatic key rotations.
  /// Set to 0 to disable automatic rotation.
  final int keyRotationDays;

  /// Default configuration for production.
  static const production = EncryptionConfig();

  /// Configuration for development (less strict).
  static const development = EncryptionConfig(
    enableDatabaseEncryption: false,
    enableAtRestEncryption: false,
    keyRotationDays: 0,
  );
}

