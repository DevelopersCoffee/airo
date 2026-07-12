import 'package:shared_preferences/shared_preferences.dart';

import 'android_finance_import_service.dart';

class AndroidFinanceImportPreferences {
  const AndroidFinanceImportPreferences();

  static const String preferenceKey = 'coins_android_finance_import_enabled';

  Future<AndroidFinanceImportPermission> readPermission() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(preferenceKey) ?? false;
    return enabled
        ? AndroidFinanceImportPermission.enabled
        : AndroidFinanceImportPermission.disabled;
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(preferenceKey, enabled);
  }
}
