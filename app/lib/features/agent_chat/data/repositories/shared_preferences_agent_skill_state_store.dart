import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferencesAgentSkillStateStore {
  SharedPreferencesAgentSkillStateStore(this._preferences);

  static const _enabledStateKey = 'agent_skills.enabled_state.v1';

  final SharedPreferences _preferences;

  Map<String, bool> loadEnabledState() {
    final raw = _preferences.getString(_enabledStateKey);
    if (raw == null || raw.isEmpty) return const {};

    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return const {};

    return decoded.map((key, value) => MapEntry(key, value == true));
  }

  Future<void> saveEnabledState(Map<String, bool> enabledState) {
    return _preferences.setString(_enabledStateKey, jsonEncode(enabledState));
  }
}
