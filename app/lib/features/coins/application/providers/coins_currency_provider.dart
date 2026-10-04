import 'dart:ui';

import 'package:core_app_shell/core_app_shell.dart';
import 'package:feature_coins_core/feature_coins_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Device-local Coins display currency (not synced to cloud).
class CoinsCurrencyState {
  const CoinsCurrencyState({
    required this.currencyCode,
    required this.userSelected,
  });

  final String currencyCode;
  final bool userSelected;
}

class CoinsCurrencyNotifier extends StateNotifier<CoinsCurrencyState> {
  CoinsCurrencyNotifier(this._prefs)
    : super(
        CoinsCurrencyState(
          currencyCode: CurrencyCode.inr.code,
          userSelected: false,
        ),
      ) {
    _load();
  }

  static const _codeKey = 'airo_coins_currency_code';
  static const _userSelectedKey = 'airo_coins_currency_user_selected';

  final SharedPreferences _prefs;

  Future<void> _load() async {
    final userSelected = _prefs.getBool(_userSelectedKey) ?? false;
    final savedCode = _prefs.getString(_codeKey);
    if (userSelected && savedCode != null && savedCode.trim().isNotEmpty) {
      state = CoinsCurrencyState(
        currencyCode: savedCode.trim().toUpperCase(),
        userSelected: true,
      );
      return;
    }

    final locale = PlatformDispatcher.instance.locale.toString();
    final timeZone = DateTime.now().timeZoneName;
    final resolved = CoinsCurrencyDefaults.resolve(
      userSelectedCode: null,
      platformLocale: locale,
      timeZoneName: timeZone,
    );
    state = CoinsCurrencyState(currencyCode: resolved, userSelected: false);
  }

  Future<void> setCurrencyCode(String code) async {
    final normalized = code.trim().toUpperCase();
    await _prefs.setString(_codeKey, normalized);
    await _prefs.setBool(_userSelectedKey, true);
    state = CoinsCurrencyState(currencyCode: normalized, userSelected: true);
  }
}

final coinsCurrencyProvider =
    StateNotifierProvider<CoinsCurrencyNotifier, CoinsCurrencyState>((ref) {
      throw UnimplementedError(
        'Override coinsCurrencyProvider with SharedPreferences in app bootstrap',
      );
    });

final coinsCurrencyFormatterProvider = Provider<CurrencyFormatter>((ref) {
  final settings = ref.watch(coinsCurrencyProvider);
  return CurrencyFormatter.fromCode(settings.currencyCode);
});
