import 'package:airo_app/features/coins/application/providers/coins_currency_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Bootstrap override for widget/unit tests after #2090 local currency state.
Future<Override> coinsCurrencyProviderTestOverride({
  String currencyCode = 'INR',
}) async {
  final normalized = currencyCode.trim().toUpperCase();
  SharedPreferences.setMockInitialValues({
    'airo_coins_currency_code': normalized,
    'airo_coins_currency_user_selected': true,
  });
  final prefs = await SharedPreferences.getInstance();
  return coinsCurrencyProvider.overrideWith((ref) => CoinsCurrencyNotifier(prefs));
}
