import 'dart:convert';

import 'package:core_data/core_data.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferencesAgentSkillStateStore {
  SharedPreferencesAgentSkillStateStore(
    this._preferences, {
    KeyValueStore? store,
    int maxPreferenceValueBytes = kKeyValueStorePreferenceMaxValueBytes,
  }) : _store =
           store ??
           PreferencesStore(
             _preferences,
             maxValueBytes: maxPreferenceValueBytes,
           );

  static const _enabledStateKey = 'agent_skills.enabled_state.v1';

  final SharedPreferences _preferences;
  final KeyValueStore _store;

  Map<String, bool> loadEnabledState() {
    final raw = _preferences.getString(_enabledStateKey);
    if (raw == null || raw.isEmpty) return const {};

    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return const {};

    return decoded.map((key, value) => MapEntry(key, value == true));
  }

  Future<void> saveEnabledState(Map<String, bool> enabledState) async {
    try {
      await _store.setString(_enabledStateKey, jsonEncode(enabledState));
    } on KeyValueStoreValueTooLargeException catch (e) {
      await _store.remove(_enabledStateKey);
      debugPrint('Agent Skill state exceeded preference tier: $e');
    }
  }
}
