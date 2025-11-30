/// Abstract interface for key-value storage operations.
///
/// This abstraction allows for different storage backends
/// (SharedPreferences, Hive, secure storage, etc.)
abstract class KeyValueStore {
  /// Gets a string value
  Future<String?> getString(String key);

  /// Sets a string value
  Future<bool> setString(String key, String value);

  /// Gets an int value
  Future<int?> getInt(String key);

  /// Sets an int value
  Future<bool> setInt(String key, int value);

  /// Gets a double value
  Future<double?> getDouble(String key);

  /// Sets a double value
  Future<bool> setDouble(String key, double value);

  /// Gets a bool value
  Future<bool?> getBool(String key);

  /// Sets a bool value
  Future<bool> setBool(String key, {required bool value});

  /// Gets a list of strings
  Future<List<String>?> getStringList(String key);

  /// Sets a list of strings
  Future<bool> setStringList(String key, List<String> value);

  /// Checks if a key exists
  Future<bool> containsKey(String key);

  /// Removes a value by key
  Future<bool> remove(String key);

  /// Clears all stored values
  Future<bool> clear();
}

