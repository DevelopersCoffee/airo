import 'package:core_ui/core_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists and exposes the selected app theme.
class AppThemeNotifier extends StateNotifier<AppThemeId> {
  static const String storageKey = 'airo_app_theme_id';

  SharedPreferences? _preferences;

  AppThemeNotifier() : super(AppTheme.defaultThemeId) {
    _load();
  }

  AppThemeNotifier.withPreferences(SharedPreferences preferences)
    : _preferences = preferences,
      super(AppThemeId.fromStorageValue(preferences.getString(storageKey)));

  AppThemeDefinition get currentTheme => AppTheme.byId(state);

  Future<void> setTheme(AppThemeId themeId) async {
    state = themeId;
    final preferences = _preferences ?? await SharedPreferences.getInstance();
    _preferences = preferences;
    await preferences.setString(storageKey, themeId.storageValue);
  }

  Future<void> _load() async {
    final preferences = await SharedPreferences.getInstance();
    _preferences = preferences;
    state = AppThemeId.fromStorageValue(preferences.getString(storageKey));
  }
}

final appThemeProvider = StateNotifierProvider<AppThemeNotifier, AppThemeId>((
  ref,
) {
  return AppThemeNotifier();
});

final appThemeDefinitionProvider = Provider<AppThemeDefinition>((ref) {
  final themeId = ref.watch(appThemeProvider);
  return AppTheme.byId(themeId);
});
