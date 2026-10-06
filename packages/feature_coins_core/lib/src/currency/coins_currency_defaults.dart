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
    'IN': 'INR',
    'US': 'USD',
    'GB': 'GBP',
    'UK': 'GBP',
    'DE': 'EUR',
    'FR': 'EUR',
    'IT': 'EUR',
    'ES': 'EUR',
    'NL': 'EUR',
    'JP': 'JPY',
    'CA': 'CAD',
    'AU': 'AUD',
    'SG': 'SGD',
    'AE': 'AED',
  };

  static const Map<String, String> _languageToCurrency = {'hi': 'INR'};

  static const List<({String pattern, String currencyCode})>
  _timeZoneCurrencyEntries = [
    (pattern: 'Kolkata', currencyCode: 'INR'),
    (pattern: 'India', currencyCode: 'INR'),
    (pattern: 'IST', currencyCode: 'INR'),
    (pattern: 'New_York', currencyCode: 'USD'),
    (pattern: 'Chicago', currencyCode: 'USD'),
    (pattern: 'Los_Angeles', currencyCode: 'USD'),
    (pattern: 'America/', currencyCode: 'USD'),
    (pattern: 'London', currencyCode: 'GBP'),
    (pattern: 'Europe/London', currencyCode: 'GBP'),
    (pattern: 'Berlin', currencyCode: 'EUR'),
    (pattern: 'Paris', currencyCode: 'EUR'),
    (pattern: 'Europe/', currencyCode: 'EUR'),
    (pattern: 'Tokyo', currencyCode: 'JPY'),
    (pattern: 'Sydney', currencyCode: 'AUD'),
    (pattern: 'Singapore', currencyCode: 'SGD'),
    (pattern: 'Dubai', currencyCode: 'AED'),
  ];
}
