import 'package:flutter_test/flutter_test.dart';
import 'package:airo_app/core/utils/currency_formatter.dart';

void main() {
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

  group('IndianDateFormatter', () {
    test('should format date in dd/MM/yyyy format', () {
      final date = DateTime(2025, 11, 30);
      expect(IndianDateFormatter.formatDate(date), '30/11/2025');
    });

    test('should format date and time correctly', () {
      final date = DateTime(2025, 11, 30, 14, 30);
      expect(IndianDateFormatter.formatDateTime(date), '30/11/2025 14:30');
    });

    test('should format time correctly', () {
      final date = DateTime(2025, 11, 30, 14, 30);
      expect(IndianDateFormatter.formatTime(date), '14:30');
    });

    test('should format month year correctly', () {
      final date = DateTime(2025, 11, 30);
      expect(IndianDateFormatter.formatMonthYear(date), 'November 2025');
    });

    test('should format short date correctly', () {
      final date = DateTime(2025, 11, 30);
      expect(IndianDateFormatter.formatShortDate(date), '30 Nov');
    });

    test('should parse date string correctly', () {
      final parsed = IndianDateFormatter.parseDate('30/11/2025');
      expect(parsed, isNotNull);
      expect(parsed!.day, 30);
      expect(parsed.month, 11);
      expect(parsed.year, 2025);
    });

    test('should return null for invalid date string', () {
      expect(IndianDateFormatter.parseDate('invalid'), null);
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
