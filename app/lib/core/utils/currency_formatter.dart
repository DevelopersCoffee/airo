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

/// Date formatter for Indian locale
class IndianDateFormatter {
  static final DateFormat _dateFormat = DateFormat('dd/MM/yyyy', 'en_IN');
  static final DateFormat _dateTimeFormat = DateFormat(
    'dd/MM/yyyy HH:mm',
    'en_IN',
  );
  static final DateFormat _timeFormat = DateFormat('HH:mm', 'en_IN');
  static final DateFormat _monthYearFormat = DateFormat('MMMM yyyy', 'en_IN');
  static final DateFormat _shortDateFormat = DateFormat('dd MMM', 'en_IN');

  /// Format date as dd/MM/yyyy
  static String formatDate(DateTime date) => _dateFormat.format(date);

  /// Format date and time as dd/MM/yyyy HH:mm
  static String formatDateTime(DateTime date) => _dateTimeFormat.format(date);

  /// Format time as HH:mm
  static String formatTime(DateTime date) => _timeFormat.format(date);

  /// Format as Month Year (e.g., November 2025)
  static String formatMonthYear(DateTime date) => _monthYearFormat.format(date);

  /// Format as short date (e.g., 30 Nov)
  static String formatShortDate(DateTime date) => _shortDateFormat.format(date);

  /// Parse dd/MM/yyyy string to DateTime
  static DateTime? parseDate(String dateStr) {
    try {
      return _dateFormat.parse(dateStr);
    } catch (e) {
      return null;
    }
  }
}
