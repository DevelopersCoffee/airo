import 'dart:convert';

import 'package:airo_app/core/utils/locale_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('LocaleSettingsNotifier', () {
    test(
      'loads the selected profile currency before stale standalone settings',
      () async {
        final profileJson = _profileJson(localeSettings: LocaleSettings.india);
        SharedPreferences.setMockInitialValues({
          'airo_current_user_id': 'user_1',
          'airo_locale_settings': jsonEncode(LocaleSettings.us.toJson()),
          'airo_user_profile_user_1': jsonEncode(profileJson),
        });

        final notifier = LocaleSettingsNotifier();
        await pumpEventQueue();

        expect(notifier.state.currency, 'INR');
        expect(notifier.state.currencyFormatter.currency.symbol, '₹');
      },
    );

    test('persists currency updates back to the current profile', () async {
      final profileJson = _profileJson(localeSettings: LocaleSettings.us);
      SharedPreferences.setMockInitialValues({
        'airo_current_user_id': 'user_1',
        'airo_user_profile_user_1': jsonEncode(profileJson),
      });

      final notifier = LocaleSettingsNotifier();
      await pumpEventQueue();

      await notifier.setCurrency('INR');

      final prefs = await SharedPreferences.getInstance();
      final updatedProfile =
          jsonDecode(prefs.getString('airo_user_profile_user_1')!)
              as Map<String, dynamic>;
      final updatedLocale =
          updatedProfile['localeSettings'] as Map<String, dynamic>;

      expect(updatedLocale['currency'], 'INR');
      expect(updatedLocale['locale'], 'en_US');
    });

    test(
      'does not overwrite profile when updated profile exceeds prefs tier',
      () async {
        final profileJson = _profileJson(
          localeSettings: LocaleSettings.us,
          displayName: 'Uday ${List.filled(512, 'x').join()}',
        );
        final originalProfileJson = jsonEncode(profileJson);
        SharedPreferences.setMockInitialValues({
          'airo_current_user_id': 'user_1',
          'airo_user_profile_user_1': originalProfileJson,
        });

        final notifier = LocaleSettingsNotifier(maxPreferenceValueBytes: 256);
        await pumpEventQueue();

        await notifier.setCurrency('INR');

        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getString('airo_user_profile_user_1'),
          originalProfileJson,
        );
        expect(notifier.state.currency, 'INR');
      },
    );
  });
}

Map<String, dynamic> _profileJson({
  required LocaleSettings localeSettings,
  String displayName = 'Uday',
}) {
  return {
    'id': 'user_1',
    'username': 'uday',
    'displayName': displayName,
    'email': 'uday@example.com',
    'avatarUrl': null,
    'phoneNumber': null,
    'localeSettings': localeSettings.toJson(),
    'createdAt': DateTime(2026, 5, 15).toIso8601String(),
    'updatedAt': DateTime(2026, 5, 15).toIso8601String(),
    'preferences': null,
  };
}
