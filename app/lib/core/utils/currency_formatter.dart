import 'package:intl/intl.dart';

/// Currency codes supported by the app
enum SupportedCurrency {
  inr('INR', '₹', 'en_IN'),
  usd('USD', '\$', 'en_US'),
  eur('EUR', '€', 'de_DE'),
  gbp('GBP', '£', 'en_GB');

  final String code;
  final String symbol;
  final String locale;

  const SupportedCurrency(this.code, this.symbol, this.locale);

  static SupportedCurrency fromCode(String code) {
    return SupportedCurrency.values.firstWhere(
      (c) => c.code.toUpperCase() == code.toUpperCase(),
      orElse: () => SupportedCurrency.inr, // Default to INR
    );
  }
}

/// Locale configuration for date/time formatting
class LocaleConfig {
  final String locale;
  final String dateFormat;
  final String dateTimeFormat;
  final String timeFormat;
  final String monthYearFormat;
  final String shortDateFormat;

  const LocaleConfig({
    required this.locale,
    required this.dateFormat,
    required this.dateTimeFormat,
    required this.timeFormat,
    required this.monthYearFormat,
    required this.shortDateFormat,
  });

  /// Indian locale configuration (dd/MM/yyyy)
  static const india = LocaleConfig(
    locale: 'en_IN',
    dateFormat: 'dd/MM/yyyy',
    dateTimeFormat: 'dd/MM/yyyy HH:mm',
    timeFormat: 'HH:mm',
    monthYearFormat: 'MMMM yyyy',
    shortDateFormat: 'dd MMM',
  );

  /// US locale configuration (MM/dd/yyyy)
  static const us = LocaleConfig(
    locale: 'en_US',
    dateFormat: 'MM/dd/yyyy',
    dateTimeFormat: 'MM/dd/yyyy h:mm a',
    timeFormat: 'h:mm a',
    monthYearFormat: 'MMMM yyyy',
    shortDateFormat: 'MMM dd',
  );

  /// EU locale configuration (dd.MM.yyyy)
  static const eu = LocaleConfig(
    locale: 'de_DE',
    dateFormat: 'dd.MM.yyyy',
    dateTimeFormat: 'dd.MM.yyyy HH:mm',
    timeFormat: 'HH:mm',
    monthYearFormat: 'MMMM yyyy',
    shortDateFormat: 'dd. MMM',
  );

  /// UK locale configuration (dd/MM/yyyy)
  static const uk = LocaleConfig(
    locale: 'en_GB',
    dateFormat: 'dd/MM/yyyy',
    dateTimeFormat: 'dd/MM/yyyy HH:mm',
    timeFormat: 'HH:mm',
    monthYearFormat: 'MMMM yyyy',
    shortDateFormat: 'dd MMM',
  );

  /// Get config for a locale string
  static LocaleConfig fromLocale(String locale) {
    switch (locale) {
      case 'en_US':
        return us;
      case 'de_DE':
        return eu;
      case 'en_GB':
        return uk;
      case 'en_IN':
      default:
        return india;
    }
  }
}

/// Utility class for formatting currency amounts
/// Handles cents to display conversion with proper locale formatting
class CurrencyFormatter {
  final SupportedCurrency currency;
  final NumberFormat _formatter;
  final NumberFormat _compactFormatter;

  CurrencyFormatter._({
    required this.currency,
    required NumberFormat formatter,
    required NumberFormat compactFormatter,
  }) : _formatter = formatter,
       _compactFormatter = compactFormatter;

  /// Create formatter for a specific currency
  factory CurrencyFormatter.forCurrency(SupportedCurrency currency) {
    return CurrencyFormatter._(
      currency: currency,
      formatter: NumberFormat.currency(
        locale: currency.locale,
        symbol: currency.symbol,
        decimalDigits: 2,
      ),
      compactFormatter: NumberFormat.compactCurrency(
        locale: currency.locale,
        symbol: currency.symbol,
        decimalDigits: 0,
      ),
    );
  }

  /// Create formatter from currency code string
  factory CurrencyFormatter.fromCode(String currencyCode) {
    return CurrencyFormatter.forCurrency(
      SupportedCurrency.fromCode(currencyCode),
    );
  }

  /// Default formatter for Indian Rupees
  static CurrencyFormatter get inr =>
      CurrencyFormatter.forCurrency(SupportedCurrency.inr);

  /// Format amount in cents to display string
  /// Example: 250050 cents -> ₹2,500.50
  String formatCents(int cents) {
    final amount = cents / 100.0;
    return _formatter.format(amount);
  }

  /// Format amount (already in main units) to display string
  /// Example: 2500.50 -> ₹2,500.50
  String format(double amount) {
    return _formatter.format(amount);
  }

  /// Format amount in compact form (for large amounts)
  /// Example: 2500000 cents -> ₹25K
  String formatCentsCompact(int cents) {
    final amount = cents / 100.0;
    return _compactFormatter.format(amount);
  }

  /// Format with sign (+ for positive, - for negative)
  /// Example: 250050 cents -> +₹2,500.50
  String formatCentsWithSign(int cents) {
    final formatted = formatCents(cents.abs());
    if (cents > 0) return '+$formatted';
    if (cents < 0) return '-$formatted';
    return formatted;
  }

  /// Parse formatted string back to cents
  /// Returns null if parsing fails
  int? parseToCents(String formattedAmount) {
    try {
      // Remove currency symbol and whitespace
      final cleaned = formattedAmount
          .replaceAll(currency.symbol, '')
          .replaceAll(',', '')
          .replaceAll(' ', '')
          .trim();

      final amount = double.parse(cleaned);
      return (amount * 100).round();
    } catch (e) {
      return null;
    }
  }
}

/// Locale-aware date formatter that supports multiple regions
///
/// Use this instead of hardcoded date formatters for global scalability.
/// The formatter lazily initializes DateFormat instances based on locale config.
class LocaleDateFormatter {
  final LocaleConfig config;

  // Lazy-initialized formatters
  DateFormat? _dateFormat;
  DateFormat? _dateTimeFormat;
  DateFormat? _timeFormat;
  DateFormat? _monthYearFormat;
  DateFormat? _shortDateFormat;

  LocaleDateFormatter(this.config);

  /// Create formatter for a specific locale string
  factory LocaleDateFormatter.forLocale(String locale) {
    return LocaleDateFormatter(LocaleConfig.fromLocale(locale));
  }

  /// Default Indian locale formatter
  static LocaleDateFormatter get india =>
      LocaleDateFormatter(LocaleConfig.india);

  /// US locale formatter
  static LocaleDateFormatter get us => LocaleDateFormatter(LocaleConfig.us);

  /// EU locale formatter
  static LocaleDateFormatter get eu => LocaleDateFormatter(LocaleConfig.eu);

  /// UK locale formatter
  static LocaleDateFormatter get uk => LocaleDateFormatter(LocaleConfig.uk);

  DateFormat get _date =>
      _dateFormat ??= DateFormat(config.dateFormat, config.locale);

  DateFormat get _dateTime =>
      _dateTimeFormat ??= DateFormat(config.dateTimeFormat, config.locale);

  DateFormat get _time =>
      _timeFormat ??= DateFormat(config.timeFormat, config.locale);

  DateFormat get _monthYear =>
      _monthYearFormat ??= DateFormat(config.monthYearFormat, config.locale);

  DateFormat get _shortDate =>
      _shortDateFormat ??= DateFormat(config.shortDateFormat, config.locale);

  /// Format date according to locale (e.g., dd/MM/yyyy or MM/dd/yyyy)
  String formatDate(DateTime date) => _date.format(date);

  /// Format date and time according to locale
  String formatDateTime(DateTime date) => _dateTime.format(date);

  /// Format time according to locale
  String formatTime(DateTime date) => _time.format(date);

  /// Format as Month Year (e.g., November 2025)
  String formatMonthYear(DateTime date) => _monthYear.format(date);

  /// Format as short date according to locale (e.g., 30 Nov or Nov 30)
  String formatShortDate(DateTime date) => _shortDate.format(date);

  /// Parse date string according to locale format
  DateTime? parseDate(String dateStr) {
    try {
      return _date.parse(dateStr);
    } catch (e) {
      return null;
    }
  }

  /// Parse date string trying multiple common formats
  /// Useful for OCR output that may have various date formats
  DateTime? parseDateFlexible(String dateStr) {
    // Try common formats in order of likelihood
    final formats = [
      config.dateFormat,
      'dd/MM/yyyy',
      'MM/dd/yyyy',
      'yyyy-MM-dd',
      'dd.MM.yyyy',
      'dd-MM-yyyy',
      'MM-dd-yyyy',
    ];

    for (final format in formats) {
      try {
        // Use parseStrict to avoid lenient parsing (e.g., month 30 wrapping)
        return DateFormat(format).parseStrict(dateStr);
      } catch (_) {
        continue;
      }
    }
    return null;
  }
}

/// Date formatter for Indian locale
/// @deprecated Use LocaleDateFormatter instead for global scalability
@Deprecated('Use LocaleDateFormatter.india instead for global scalability')
class IndianDateFormatter {
  static LocaleDateFormatter? _formatter;

  static LocaleDateFormatter get _instance =>
      _formatter ??= LocaleDateFormatter.india;

  /// Format date as dd/MM/yyyy
  static String formatDate(DateTime date) => _instance.formatDate(date);

  /// Format date and time as dd/MM/yyyy HH:mm
  static String formatDateTime(DateTime date) => _instance.formatDateTime(date);

  /// Format time as HH:mm
  static String formatTime(DateTime date) => _instance.formatTime(date);

  /// Format as Month Year (e.g., November 2025)
  static String formatMonthYear(DateTime date) =>
      _instance.formatMonthYear(date);

  /// Format as short date (e.g., 30 Nov)
  static String formatShortDate(DateTime date) =>
      _instance.formatShortDate(date);

  /// Parse dd/MM/yyyy string to DateTime
  static DateTime? parseDate(String dateStr) => _instance.parseDate(dateStr);

  /// Reset the cached formatter (useful for testing)
  static void reset() {
    _formatter = null;
  }
}
