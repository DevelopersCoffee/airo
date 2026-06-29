import 'package:design_system/design_system.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists and exposes the selected app theme.
class AppThemeNotifier extends StateNotifier<AppThemeId> {
  static const String storageKey = 'airo_app_theme_id';
  static const String bedtimeMigrationKey =
      'airo_bedtime_theme_default_migrated';

  SharedPreferences? _preferences;

  AppThemeNotifier() : super(AppTheme.defaultThemeId) {
    _load();
  }

  AppThemeNotifier.withPreferences(SharedPreferences preferences)
    : _preferences = preferences,
      super(_themeFromPreferences(preferences));

  AppThemeDefinition get currentTheme => AppTheme.byId(state);

  Future<void> setTheme(AppThemeId themeId) async {
    state = themeId;
    final preferences = _preferences ?? await SharedPreferences.getInstance();
    _preferences = preferences;
    await preferences.setString(storageKey, themeId.storageValue);
  }

  Future<void> resetToDefault() async {
    await setTheme(AppTheme.defaultThemeId);
  }

  Future<void> _load() async {
    final preferences = await SharedPreferences.getInstance();
    _preferences = preferences;
    state = _themeFromPreferences(preferences);
  }

  static AppThemeId _themeFromPreferences(SharedPreferences preferences) {
    final savedTheme = AppThemeId.fromStorageValue(
      preferences.getString(storageKey),
    );
    final migrated = preferences.getBool(bedtimeMigrationKey) ?? false;
    if (savedTheme == AppThemeId.bedtime && !migrated) {
      preferences.setString(storageKey, AppTheme.defaultThemeId.storageValue);
      preferences.setBool(bedtimeMigrationKey, true);
      return AppTheme.defaultThemeId;
    }
    return savedTheme;
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
