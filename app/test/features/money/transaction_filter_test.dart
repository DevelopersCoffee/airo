import 'package:flutter_test/flutter_test.dart';
import 'package:airo_app/features/money/application/providers/money_provider.dart';

void main() {
  group('TransactionFilter', () {
    test('should create empty filter by default', () {
      const filter = TransactionFilter();

      expect(filter.category, isNull);
      expect(filter.startDate, isNull);
      expect(filter.endDate, isNull);
    });

    test('should create filter with category', () {
      const filter = TransactionFilter(category: 'Food & Drink');

      expect(filter.category, 'Food & Drink');
      expect(filter.startDate, isNull);
      expect(filter.endDate, isNull);
    });

    test('should create filter with date range', () {
      final start = DateTime(2024, 1, 1);
      final end = DateTime(2024, 1, 31);
      final filter = TransactionFilter(startDate: start, endDate: end);

      expect(filter.category, isNull);
      expect(filter.startDate, start);
      expect(filter.endDate, end);
    });

    test('should create filter with all fields', () {
      final start = DateTime(2024, 1, 1);
      final end = DateTime(2024, 1, 31);
      final filter = TransactionFilter(
        category: 'Food & Drink',
        startDate: start,
        endDate: end,
      );

      expect(filter.category, 'Food & Drink');
      expect(filter.startDate, start);
      expect(filter.endDate, end);
    });

    test('copyWith should update category', () {
      const original = TransactionFilter(category: 'Food');
      final updated = original.copyWith(category: 'Transport');

      expect(updated.category, 'Transport');
      expect(original.category, 'Food'); // Original unchanged
    });

    test('copyWith should update dates', () {
      const original = TransactionFilter();
      final newDate = DateTime(2024, 6, 15);
      final updated = original.copyWith(startDate: newDate);

      expect(updated.startDate, newDate);
      expect(original.startDate, isNull); // Original unchanged
    });

    test('copyWith should clear category when clearCategory is true', () {
      const original = TransactionFilter(category: 'Food');
      final updated = original.copyWith(clearCategory: true);

      expect(updated.category, isNull);
    });

    test('copyWith should clear startDate when clearStartDate is true', () {
      final original = TransactionFilter(startDate: DateTime(2024, 1, 1));
      final updated = original.copyWith(clearStartDate: true);

      expect(updated.startDate, isNull);
    });

    test('copyWith should clear endDate when clearEndDate is true', () {
      final original = TransactionFilter(endDate: DateTime(2024, 12, 31));
      final updated = original.copyWith(clearEndDate: true);

      expect(updated.endDate, isNull);
    });

    test('copyWith should preserve unchanged fields', () {
      final start = DateTime(2024, 1, 1);
      final end = DateTime(2024, 12, 31);
      final original = TransactionFilter(
        category: 'Food',
        startDate: start,
        endDate: end,
      );
      final updated = original.copyWith(category: 'Transport');

      expect(updated.category, 'Transport');
      expect(updated.startDate, start); // Preserved
      expect(updated.endDate, end); // Preserved
    });

    test('copyWith without parameters should return equivalent filter', () {
      final start = DateTime(2024, 1, 1);
      final original = TransactionFilter(category: 'Food', startDate: start);
      final updated = original.copyWith();

      expect(updated.category, original.category);
      expect(updated.startDate, original.startDate);
      expect(updated.endDate, original.endDate);
    });
  });
}
