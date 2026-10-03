import '../models/currency.dart';

/// Resolves the display currency for Airo Coins when the user has not chosen one.
class CoinsCurrencyDefaults {
  const CoinsCurrencyDefaults._();

  /// When [userSelectedCode] is non-null, it always wins.
  ///
  /// Otherwise prefers [platformLocale], then [timeZoneName], then INR.
  static String resolve({
    String? userSelectedCode,
    required String platformLocale,
    required String timeZoneName,
  }) {
    final trimmedChoice = userSelectedCode?.trim();
    if (trimmedChoice != null && trimmedChoice.isNotEmpty) {
      return trimmedChoice.toUpperCase();
    }

    final fromLocale = _currencyForLocale(platformLocale);
    if (fromLocale != null) {
      return fromLocale;
    }

    final fromTimeZone = _currencyForTimeZone(timeZoneName);
    if (fromTimeZone != null) {
      return fromTimeZone;
    }

    return CurrencyCode.inr.code;
  }

  static String? _currencyForLocale(String locale) {
    final normalized = locale.replaceAll('-', '_');
    final segments = normalized.split('_');
    if (segments.isEmpty) return null;

    final language = segments.first.toLowerCase();
    final region = segments.length > 1 ? segments[1].toUpperCase() : '';

    if (region.isNotEmpty) {
      final byRegion = _regionToCurrency[region];
      if (byRegion != null) return byRegion;
    }

    return _languageToCurrency[language];
  }

  static String? _currencyForTimeZone(String timeZoneName) {
    final normalized = timeZoneName.trim();
    if (normalized.isEmpty) return null;

    for (final entry in _timeZoneCurrencyEntries) {
      if (normalized.contains(entry.pattern) ||
          normalized.toUpperCase().contains(entry.pattern.toUpperCase())) {
        return entry.currencyCode;
      }
    }
    return null;
  }

  static const Map<String, String> _regionToCurrency = {
    'IN': CurrencyCode.inr.code,
    'US': CurrencyCode.usd.code,
    'GB': CurrencyCode.gbp.code,
    'UK': CurrencyCode.gbp.code,
    'DE': CurrencyCode.eur.code,
    'FR': CurrencyCode.eur.code,
    'IT': CurrencyCode.eur.code,
    'ES': CurrencyCode.eur.code,
    'NL': CurrencyCode.eur.code,
    'JP': CurrencyCode.jpy.code,
    'CA': CurrencyCode.cad.code,
    'AU': CurrencyCode.aud.code,
    'SG': CurrencyCode.sgd.code,
    'AE': CurrencyCode.aed.code,
  };

  static const Map<String, String> _languageToCurrency = {
    'hi': CurrencyCode.inr.code,
  };

  static const List<({String pattern, String currencyCode})>
  _timeZoneCurrencyEntries = [
    (pattern: 'Kolkata', currencyCode: CurrencyCode.inr.code),
    (pattern: 'India', currencyCode: CurrencyCode.inr.code),
    (pattern: 'IST', currencyCode: CurrencyCode.inr.code),
    (pattern: 'New_York', currencyCode: CurrencyCode.usd.code),
    (pattern: 'Chicago', currencyCode: CurrencyCode.usd.code),
    (pattern: 'Los_Angeles', currencyCode: CurrencyCode.usd.code),
    (pattern: 'America/', currencyCode: CurrencyCode.usd.code),
    (pattern: 'London', currencyCode: CurrencyCode.gbp.code),
    (pattern: 'Europe/London', currencyCode: CurrencyCode.gbp.code),
    (pattern: 'Berlin', currencyCode: CurrencyCode.eur.code),
    (pattern: 'Paris', currencyCode: CurrencyCode.eur.code),
    (pattern: 'Europe/', currencyCode: CurrencyCode.eur.code),
    (pattern: 'Tokyo', currencyCode: CurrencyCode.jpy.code),
    (pattern: 'Sydney', currencyCode: CurrencyCode.aud.code),
    (pattern: 'Singapore', currencyCode: CurrencyCode.sgd.code),
    (pattern: 'Dubai', currencyCode: CurrencyCode.aed.code),
  ];
}
