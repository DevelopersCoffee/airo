import 'package:airo_app/features/coins/application/providers/coins_currency_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Matches app bootstrap: [coinsCurrencyProvider] needs [SharedPreferences].
Override coinsCurrencyProviderTestOverride(SharedPreferences prefs) {
  return coinsCurrencyProvider.overrideWith(
    (ref) => CoinsCurrencyNotifier(prefs),
  );
}
