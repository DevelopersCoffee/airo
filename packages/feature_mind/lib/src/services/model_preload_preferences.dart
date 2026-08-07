import 'package:core_ai/core_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Airo's persistence adapter for the reusable model-manager preload contract.
class SharedPreferencesModelPreloadPreferences
    implements ModelPreloadPreferences {
  SharedPreferencesModelPreloadPreferences([this._preferences]);

  static const storageKey = 'frequently_preloaded_model_ids';

  final SharedPreferences? _preferences;

  Future<SharedPreferences> _resolve() async {
    final preferences = _preferences;
    return preferences ?? SharedPreferences.getInstance();
  }

  @override
  Future<Set<String>> loadModelIds() async {
    final preferences = await _resolve();
    return preferences.getStringList(storageKey)?.toSet() ?? <String>{};
  }

  @override
  Future<void> setEnabled(String modelId, bool enabled) async {
    final preferences = await _resolve();
    final ids = preferences.getStringList(storageKey)?.toSet() ?? <String>{};
    enabled ? ids.add(modelId) : ids.remove(modelId);
    final ordered = ids.toList()..sort();
    await preferences.setStringList(storageKey, ordered);
  }
}
