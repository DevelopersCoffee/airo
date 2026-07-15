/// Abstract interface for key-value storage operations.
///
/// This is the **prefs tier** (see ADR-0008). It is intended for small values
/// only: boolean flags, short strings, ints. Do NOT store large blobs, JSON
/// payloads, or serialised collections here -- use Drift/SQLite (structured
/// tier) or file storage instead.
///
/// A debug assertion rejects string values larger than [maxValueChars]
/// (64 KB). This fires only in debug mode and has no effect on release builds.
abstract class KeyValueStore {
  /// Maximum character length for a single string value in the prefs tier.
  /// Values exceeding this limit indicate misuse -- the data belongs in the
  /// structured tier (Drift/SQLite) or file tier (path_provider).
  static const int maxValueChars = 65536;

  /// Debug-only size guard. Call from [setString] / [setStringList]
  /// implementations to catch prefs-tier misuse during development.
  static void assertValueSize(String value, String key) {
    assert(() {
      if (value.length > maxValueChars) {
        throw StateError(
          'Value too large for prefs tier: key="$key", '
          '${value.length} chars (limit $maxValueChars). '
          'Use Drift/SQLite or file storage instead. See ADR-0008.',
        );
      }
      return true;
    }());
  }

  /// Gets a string value
  Future<String?> getString(String key);

  /// Sets a string value.
  ///
  /// In debug mode, throws [StateError] if [value] exceeds [maxValueChars].
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

  /// Sets a list of strings.
  ///
  /// In debug mode, throws [StateError] if any element exceeds
  /// [maxValueChars].
  Future<bool> setStringList(String key, List<String> value);

  /// Checks if a key exists
  Future<bool> containsKey(String key);

  /// Removes a value by key
  Future<bool> remove(String key);

  /// Clears all stored values
  Future<bool> clear();
}
