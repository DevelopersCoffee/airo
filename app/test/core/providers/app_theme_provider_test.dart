import 'package:airo_app/core/providers/app_theme_provider.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AppThemeNotifier', () {
    test('defaults to Airo Cyber when no preference exists', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final notifier = AppThemeNotifier.withPreferences(prefs);

      expect(notifier.state, AppThemeId.cyber);
      expect(notifier.currentTheme.name, 'Airo Cyber');
    });

    test('restores a persisted theme', () async {
      SharedPreferences.setMockInitialValues({
        AppThemeNotifier.storageKey: AppThemeId.classic.storageValue,
      });
      final prefs = await SharedPreferences.getInstance();
      final notifier = AppThemeNotifier.withPreferences(prefs);

      expect(notifier.state, AppThemeId.classic);
      expect(notifier.currentTheme.name, 'Airo Classic');
    });

    test('persists selected theme changes', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final notifier = AppThemeNotifier.withPreferences(prefs);

      await notifier.setTheme(AppThemeId.bedtime);

      expect(notifier.state, AppThemeId.bedtime);
      expect(prefs.getString(AppThemeNotifier.storageKey), 'bedtime');
    });
  });
}
