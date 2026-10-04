import 'package:feature_coins_core/src/currency/coins_currency_defaults.dart';
import 'package:feature_coins_core/src/models/currency.dart';
import 'package:test/test.dart';

void main() {
  group('CoinsCurrencyDefaults', () {
    test('user selection wins over locale and timezone', () {
      expect(
        CoinsCurrencyDefaults.resolve(
          userSelectedCode: 'EUR',
          platformLocale: 'en_US',
          timeZoneName: 'America/New_York',
        ),
        'EUR',
      );
    });

    test('prefers locale region when user has not chosen', () {
      expect(
        CoinsCurrencyDefaults.resolve(
          userSelectedCode: null,
          platformLocale: 'en_GB',
          timeZoneName: 'UTC',
        ),
        CurrencyCode.gbp.code,
      );
    });

    test('falls back to timezone when locale is ambiguous', () {
      expect(
        CoinsCurrencyDefaults.resolve(
          userSelectedCode: null,
          platformLocale: 'en',
          timeZoneName: 'Asia/Kolkata',
        ),
        CurrencyCode.inr.code,
      );
    });

    test('defaults to INR when locale and timezone are unusable', () {
      expect(
        CoinsCurrencyDefaults.resolve(
          userSelectedCode: null,
          platformLocale: '',
          timeZoneName: '',
        ),
        CurrencyCode.inr.code,
      );
    });
  });
}
