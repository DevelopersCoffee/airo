// ignore_for_file: avoid_unused_constructor_parameters

/// Stub for AppDatabase on web platform
/// Web uses in-memory fake repositories instead of SQLite
library;

/// Stub database class for web - not actually used
class AppDatabase {
  AppDatabase();
  AppDatabase.forTesting(dynamic e);

  /// Close the database (no-op on web)
  Future<void> close() async {}

  /// Transaction wrapper (no-op on web)
  Future<T> transaction<T>(Future<T> Function() action) async {
    return action();
  }
}

/// Stub for DatabaseConfig
class DatabaseConfig {
  static bool useEncryption = false;
  static String? _encryptionKey;

  static void setEncryptionKey(String key) {
    _encryptionKey = key;
  }

  static String? get encryptionKey => _encryptionKey;
}
