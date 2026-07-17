import 'package:core_ui/core_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists and exposes the selected app theme.
class AppThemeNotifier extends StateNotifier<AppThemeId> {
  static const String storageKey = 'airo_app_theme_id';
  static const String bedtimeMigrationKey =
      'airo_bedtime_theme_default_migrated';

  SharedPreferences? _preferences;
  final AppThemeId _defaultThemeId;

  AppThemeNotifier({AppThemeId defaultThemeId = AppTheme.defaultThemeId})
    : _defaultThemeId = defaultThemeId,
      super(defaultThemeId) {
    _load();
  }

  AppThemeNotifier.withPreferences(
    SharedPreferences preferences, {
    AppThemeId defaultThemeId = AppTheme.defaultThemeId,
  }) : _preferences = preferences,
       _defaultThemeId = defaultThemeId,
       super(_themeFromPreferences(preferences, fallback: defaultThemeId));

  AppThemeDefinition get currentTheme => AppTheme.byId(state);

  Future<void> setTheme(AppThemeId themeId) async {
    state = themeId;
    final preferences = _preferences ?? await SharedPreferences.getInstance();
    _preferences = preferences;
    await preferences.setString(storageKey, themeId.storageValue);
  }

  Future<void> resetToDefault() async {
    await setTheme(_defaultThemeId);
  }

  Future<void> _load() async {
    final preferences = await SharedPreferences.getInstance();
    _preferences = preferences;
    state = _themeFromPreferences(preferences, fallback: _defaultThemeId);
  }

  static AppThemeId _themeFromPreferences(
    SharedPreferences preferences, {
    required AppThemeId fallback,
  }) {
    final savedTheme = AppThemeId.fromStorageValue(
      preferences.getString(storageKey),
      fallback: fallback,
    );
    final migrated = preferences.getBool(bedtimeMigrationKey) ?? false;
    if (savedTheme == AppThemeId.bedtime && !migrated) {
      preferences.setString(storageKey, fallback.storageValue);
      preferences.setBool(bedtimeMigrationKey, true);
      return fallback;
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
