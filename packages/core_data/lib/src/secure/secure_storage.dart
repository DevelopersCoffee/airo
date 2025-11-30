import 'package:core_domain/core_domain.dart';

/// Interface for secure key-value storage.
///
/// Implementations should use platform-specific secure storage:
/// - Android: EncryptedSharedPreferences or Keystore
/// - iOS: Keychain
/// - Web: Encrypted localStorage (with derived key)
abstract interface class SecureStorage {
  /// Read a string value.
  Future<Result<String?>> read(String key);

  /// Write a string value.
  Future<Result<void>> write(String key, String value);

  /// Delete a value.
  Future<Result<void>> delete(String key);

  /// Delete all values.
  Future<Result<void>> deleteAll();

  /// Check if a key exists.
  Future<Result<bool>> containsKey(String key);

  /// Get all keys.
  Future<Result<List<String>>> getAllKeys();
}

/// Interface for encryption key management.
///
/// Implementations should derive keys from platform secure storage:
/// - Android: Android Keystore
/// - iOS: Keychain with kSecAttrAccessibleWhenUnlockedThisDeviceOnly
/// - Web: Derived from user password + device fingerprint
abstract interface class EncryptionKeyManager {
  /// Get or create the database encryption key.
  Future<Result<List<int>>> getDatabaseKey();

  /// Rotate the encryption key (re-encrypts data).
  Future<Result<void>> rotateKey();

  /// Check if encryption is available on this device.
  Future<bool> isEncryptionAvailable();

  /// Clear all keys (for logout/wipe).
  Future<Result<void>> clearKeys();
}

/// Configuration for encrypted database.
class EncryptedDatabaseConfig {
  /// Database file name.
  final String databaseName;

  /// Whether to use encryption.
  final bool enableEncryption;

  /// Schema version for migrations.
  final int schemaVersion;

  /// Whether to enable WAL mode for better performance.
  final bool enableWalMode;

  const EncryptedDatabaseConfig({
    required this.databaseName,
    this.enableEncryption = true,
    this.schemaVersion = 1,
    this.enableWalMode = true,
  });
}

/// Interface for encrypted database operations.
///
/// Implementations should use SQLCipher for encryption.
abstract interface class EncryptedDatabase {
  /// Initialize the database with encryption key.
  Future<Result<void>> initialize(EncryptedDatabaseConfig config);

  /// Execute a raw SQL query.
  Future<Result<List<Map<String, dynamic>>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]);

  /// Execute a raw SQL statement (INSERT, UPDATE, DELETE).
  Future<Result<int>> rawExecute(String sql, [List<Object?>? arguments]);

  /// Insert a row and return the ID.
  Future<Result<int>> insert(String table, Map<String, dynamic> values);

  /// Update rows and return count.
  Future<Result<int>> update(
    String table,
    Map<String, dynamic> values, {
    String? where,
    List<Object?>? whereArgs,
  });

  /// Delete rows and return count.
  Future<Result<int>> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  });

  /// Query rows.
  Future<Result<List<Map<String, dynamic>>>> query(
    String table, {
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? orderBy,
    int? limit,
    int? offset,
  });

  /// Run operations in a transaction.
  Future<Result<T>> transaction<T>(
    Future<T> Function(EncryptedDatabase txn) action,
  );

  /// Close the database.
  Future<Result<void>> close();

  /// Check if database is open.
  bool get isOpen;

  /// Get database path.
  String get path;
}

