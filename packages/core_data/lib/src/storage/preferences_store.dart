import 'package:shared_preferences/shared_preferences.dart';

import 'key_value_store.dart';

/// SharedPreferences implementation of KeyValueStore
class PreferencesStore implements KeyValueStore {
  PreferencesStore(this._prefs);

  final SharedPreferences _prefs;

  /// Creates a PreferencesStore instance
  static Future<PreferencesStore> create() async {
    final prefs = await SharedPreferences.getInstance();
    return PreferencesStore(prefs);
  }

  @override
  Future<String?> getString(String key) async => _prefs.getString(key);

  @override
  Future<bool> setString(String key, String value) async =>
      _prefs.setString(key, value);

  @override
  Future<int?> getInt(String key) async => _prefs.getInt(key);

  @override
  Future<bool> setInt(String key, int value) async =>
      _prefs.setInt(key, value);

  @override
  Future<double?> getDouble(String key) async => _prefs.getDouble(key);

  @override
  Future<bool> setDouble(String key, double value) async =>
      _prefs.setDouble(key, value);

  @override
  Future<bool?> getBool(String key) async => _prefs.getBool(key);

  @override
  Future<bool> setBool(String key, {required bool value}) async =>
      _prefs.setBool(key, value);

  @override
  Future<List<String>?> getStringList(String key) async =>
      _prefs.getStringList(key);

  @override
  Future<bool> setStringList(String key, List<String> value) async =>
      _prefs.setStringList(key, value);

  @override
  Future<bool> containsKey(String key) async => _prefs.containsKey(key);

  @override
  Future<bool> remove(String key) async => _prefs.remove(key);

  @override
  Future<bool> clear() async => _prefs.clear();
}

