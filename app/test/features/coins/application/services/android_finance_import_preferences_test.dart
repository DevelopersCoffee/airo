import 'package:airo_app/features/coins/application/services/android_finance_import_preferences.dart';
import 'package:airo_app/features/coins/application/services/android_finance_import_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AndroidFinanceImportPreferences', () {
    late AndroidFinanceImportPreferences preferences;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      preferences = const AndroidFinanceImportPreferences();
    });

    test('defaults to disabled on a fresh install', () async {
      final permission = await preferences.readPermission();

      expect(permission, AndroidFinanceImportPermission.disabled);
    });

    test('persists enabled state', () async {
      await preferences.setEnabled(true);

      expect(
        await preferences.readPermission(),
        AndroidFinanceImportPermission.enabled,
      );
    });

    test('persists disabled state', () async {
      await preferences.setEnabled(true);
      await preferences.setEnabled(false);

      expect(
        await preferences.readPermission(),
        AndroidFinanceImportPermission.disabled,
      );
    });
  });
}
