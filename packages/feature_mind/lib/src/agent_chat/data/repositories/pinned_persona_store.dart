import 'package:shared_preferences/shared_preferences.dart';

/// Persists the pinned Assistant across chat restarts.
class PinnedPersonaStore {
  PinnedPersonaStore();

  static const key = 'agent_chat.pinned_persona_id.v1';

  Future<String?> load() async {
    final preferences = await SharedPreferences.getInstance();
    final id = preferences.getString(key)?.trim();
    if (id == null || id.isEmpty) return null;
    return id;
  }

  Future<void> save(String? id) async {
    final preferences = await SharedPreferences.getInstance();
    final trimmed = id?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      await preferences.remove(key);
      return;
    }
    await preferences.setString(key, trimmed);
  }
}
