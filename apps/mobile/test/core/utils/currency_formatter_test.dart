import 'package:flutter_test/flutter_test.dart';
import 'package:airo_app/core/utils/currency_formatter.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  // Initialize locale data before running date formatter tests
  setUpAll(() async {
    await initializeDateFormatting('en_IN', null);
    await initializeDateFormatting('en_US', null);
    await initializeDateFormatting('en_GB', null);
    await initializeDateFormatting('de_DE', null);
  });

  group('CurrencyFormatter', () {
    group('INR Formatting', () {
      late CurrencyFormatter formatter;

      setUp(() {
        formatter = CurrencyFormatter.inr;
      });

      test('should format small amounts correctly', () {
        expect(formatter.formatCents(100), '₹1.00');
        expect(formatter.formatCents(5050), '₹50.50');
        expect(formatter.formatCents(9999), '₹99.99');
      });

      test('should format thousands correctly', () {
        expect(formatter.formatCents(100000), '₹1,000.00');
        expect(formatter.formatCents(999900), '₹9,999.00');
        expect(formatter.formatCents(1000000), '₹10,000.00');
      });

      test('should format lakhs correctly (Indian numbering)', () {
        expect(formatter.formatCents(10000000), '₹1,00,000.00');
        expect(formatter.formatCents(50000000), '₹5,00,000.00');
      });

      test('should format crores correctly (Indian numbering)', () {
        expect(formatter.formatCents(1000000000), '₹1,00,00,000.00');
      });

      test('should handle zero correctly', () {
        expect(formatter.formatCents(0), '₹0.00');
      });

      test('should format with sign correctly', () {
        expect(formatter.formatCentsWithSign(5000), '+₹50.00');
        expect(formatter.formatCentsWithSign(-5000), '-₹50.00');
        expect(formatter.formatCentsWithSign(0), '₹0.00');
      });
    });

    group('USD Formatting', () {
      late CurrencyFormatter formatter;

      setUp(() {
        formatter = CurrencyFormatter.fromCode('USD');
      });

      test('should format with dollar symbol', () {
        expect(formatter.formatCents(100), '\$1.00');
        expect(formatter.formatCents(100000), '\$1,000.00');
      });
    });

    group('parseToCents', () {
      late CurrencyFormatter formatter;

      setUp(() {
        formatter = CurrencyFormatter.inr;
      });

      test('should parse formatted string back to cents', () {
        expect(formatter.parseToCents('₹100.00'), 10000);
        expect(formatter.parseToCents('₹1,000.50'), 100050);
      });

      test('should return null for invalid input', () {
        expect(formatter.parseToCents('invalid'), null);
        expect(formatter.parseToCents(''), null);
      });
    });
  });

  group('LocaleDateFormatter', () {
    group('India locale (dd/MM/yyyy)', () {
      late LocaleDateFormatter formatter;

      setUp(() {
        formatter = LocaleDateFormatter.india;
      });

      test('should format date in dd/MM/yyyy format', () {
        final date = DateTime(2025, 11, 30);
        expect(formatter.formatDate(date), '30/11/2025');
      });

      test('should format date and time correctly', () {
        final date = DateTime(2025, 11, 30, 14, 30);
        expect(formatter.formatDateTime(date), '30/11/2025 14:30');
      });

      test('should format time correctly', () {
        final date = DateTime(2025, 11, 30, 14, 30);
        expect(formatter.formatTime(date), '14:30');
      });

      test('should format month year correctly', () {
        final date = DateTime(2025, 11, 30);
        expect(formatter.formatMonthYear(date), 'November 2025');
      });

      test('should format short date correctly', () {
        final date = DateTime(2025, 11, 30);
        expect(formatter.formatShortDate(date), '30 Nov');
      });

      test('should parse date string correctly', () {
        final parsed = formatter.parseDate('30/11/2025');
        expect(parsed, isNotNull);
        expect(parsed!.day, 30);
        expect(parsed.month, 11);
        expect(parsed.year, 2025);
      });

      test('should return null for invalid date string', () {
        expect(formatter.parseDate('invalid'), null);
      });
    });

    group('US locale (MM/dd/yyyy)', () {
      late LocaleDateFormatter formatter;

      setUp(() {
        formatter = LocaleDateFormatter.us;
      });

      test('should format date in MM/dd/yyyy format', () {
        final date = DateTime(2025, 11, 30);
        expect(formatter.formatDate(date), '11/30/2025');
      });

      test('should format date and time with AM/PM', () {
        final date = DateTime(2025, 11, 30, 14, 30);
        expect(formatter.formatDateTime(date), '11/30/2025 2:30 PM');
      });

      test('should format time with AM/PM', () {
        final date = DateTime(2025, 11, 30, 14, 30);
        expect(formatter.formatTime(date), '2:30 PM');
      });

      test('should format short date correctly', () {
        final date = DateTime(2025, 11, 30);
        expect(formatter.formatShortDate(date), 'Nov 30');
      });

      test('should parse US date format correctly', () {
        final parsed = formatter.parseDate('11/30/2025');
        expect(parsed, isNotNull);
        expect(parsed!.day, 30);
        expect(parsed.month, 11);
        expect(parsed.year, 2025);
      });
    });

    group('EU locale (dd.MM.yyyy)', () {
      late LocaleDateFormatter formatter;

      setUp(() {
        formatter = LocaleDateFormatter.eu;
      });

      test('should format date in dd.MM.yyyy format', () {
        final date = DateTime(2025, 11, 30);
        expect(formatter.formatDate(date), '30.11.2025');
      });

      test('should format date and time correctly', () {
        final date = DateTime(2025, 11, 30, 14, 30);
        expect(formatter.formatDateTime(date), '30.11.2025 14:30');
      });
    });

    group('Flexible date parsing', () {
      late LocaleDateFormatter formatter;

      setUp(() {
        formatter = LocaleDateFormatter.india;
      });

      test('should parse multiple date formats', () {
        // Indian format
        expect(formatter.parseDateFlexible('30/11/2025')?.day, 30);
        // US format
        expect(formatter.parseDateFlexible('11/30/2025')?.day, 30);
        // ISO format
        expect(formatter.parseDateFlexible('2025-11-30')?.day, 30);
        // EU format
        expect(formatter.parseDateFlexible('30.11.2025')?.day, 30);
      });

      test('should return null for unparseable dates', () {
        expect(formatter.parseDateFlexible('invalid'), null);
        expect(formatter.parseDateFlexible(''), null);
      });
    });
  });

  // Legacy IndianDateFormatter tests (deprecated but still supported)
  group('IndianDateFormatter (deprecated)', () {
    // ignore: deprecated_member_use_from_same_package
    test('should still work for backward compatibility', () {
      final date = DateTime(2025, 11, 30);
      // ignore: deprecated_member_use_from_same_package
      expect(IndianDateFormatter.formatDate(date), '30/11/2025');
    });
  });

  group('SupportedCurrency', () {
    test('should return correct currency from code', () {
      expect(SupportedCurrency.fromCode('INR'), SupportedCurrency.inr);
      expect(SupportedCurrency.fromCode('USD'), SupportedCurrency.usd);
      expect(SupportedCurrency.fromCode('EUR'), SupportedCurrency.eur);
      expect(SupportedCurrency.fromCode('GBP'), SupportedCurrency.gbp);
    });

    test('should default to INR for unknown currency', () {
      expect(SupportedCurrency.fromCode('XYZ'), SupportedCurrency.inr);
      expect(SupportedCurrency.fromCode(''), SupportedCurrency.inr);
    });

    test('should be case insensitive', () {
      expect(SupportedCurrency.fromCode('inr'), SupportedCurrency.inr);
      expect(SupportedCurrency.fromCode('Inr'), SupportedCurrency.inr);
    });
  });
}
