import 'package:flutter_test/flutter_test.dart';
import 'package:airo_app/features/coins/domain/services/split_calculator.dart';

void main() {
  late SplitCalculator calculator;

  setUp(() {
    calculator = SplitCalculatorImpl();
  });

  group('SplitCalculatorImpl', () {
    group('calculateEqualSplit', () {
      test('should return empty list for no participants', () {
        final result = calculator.calculateEqualSplit(
          sharedExpenseId: 'exp1',
          totalAmountCents: 10000,
          participantIds: [],
        );

        expect(result, isEmpty);
      });

      test('should split evenly among 2 participants', () {
        final result = calculator.calculateEqualSplit(
          sharedExpenseId: 'exp1',
          totalAmountCents: 10000, // ₹100.00
          participantIds: ['user1', 'user2'],
        );

        expect(result.length, 2);
        expect(result[0].amountCents, 5000);
        expect(result[1].amountCents, 5000);
        expect(result[0].userId, 'user1');
        expect(result[1].userId, 'user2');
      });

      test('should handle remainder when splitting ₹100 among 3', () {
        final result = calculator.calculateEqualSplit(
          sharedExpenseId: 'exp1',
          totalAmountCents: 10000, // ₹100.00
          participantIds: ['user1', 'user2', 'user3'],
        );

        expect(result.length, 3);
        // ₹100 / 3 = ₹33.33 with 1 paise remainder
        // First user gets extra paise
        expect(result[0].amountCents, 3334);
        expect(result[1].amountCents, 3333);
        expect(result[2].amountCents, 3333);

        // Total should equal original amount
        final total = result.fold<int>(
          0,
          (sum, split) => sum + split.amountCents,
        );
        expect(total, 10000);
      });

      test('should distribute remainder correctly for 7 paise among 5', () {
        // ₹0.07 among 5 people = 1 paise each + 2 paise remainder
        final result = calculator.calculateEqualSplit(
          sharedExpenseId: 'exp1',
          totalAmountCents: 7, // 7 paise
          participantIds: ['u1', 'u2', 'u3', 'u4', 'u5'],
        );

        // First 2 get 2 paise, rest get 1 paise
        expect(result[0].amountCents, 2);
        expect(result[1].amountCents, 2);
        expect(result[2].amountCents, 1);
        expect(result[3].amountCents, 1);
        expect(result[4].amountCents, 1);

        final total = result.fold<int>(
          0,
          (sum, split) => sum + split.amountCents,
        );
        expect(total, 7);
      });

      test('should set correct sharedExpenseId on splits', () {
        final result = calculator.calculateEqualSplit(
          sharedExpenseId: 'my-expense-123',
          totalAmountCents: 5000,
          participantIds: ['user1', 'user2'],
        );

        expect(result[0].sharedExpenseId, 'my-expense-123');
        expect(result[1].sharedExpenseId, 'my-expense-123');
      });

      test('should generate unique split ids', () {
        final result = calculator.calculateEqualSplit(
          sharedExpenseId: 'exp1',
          totalAmountCents: 3000,
          participantIds: ['user1', 'user2', 'user3'],
        );

        final ids = result.map((s) => s.id).toSet();
        expect(ids.length, 3); // All IDs should be unique
      });

      test('should handle single participant', () {
        final result = calculator.calculateEqualSplit(
          sharedExpenseId: 'exp1',
          totalAmountCents: 10000,
          participantIds: ['user1'],
        );

        expect(result.length, 1);
        expect(result[0].amountCents, 10000);
        expect(result[0].userId, 'user1');
      });
    });

    group('calculatePercentageSplit', () {
      test('should return empty list for no percentages', () {
        final result = calculator.calculatePercentageSplit(
          sharedExpenseId: 'exp1',
          totalAmountCents: 10000,
          percentages: {},
        );

        expect(result, isEmpty);
      });

      test('should split by percentage correctly', () {
        final result = calculator.calculatePercentageSplit(
          sharedExpenseId: 'exp1',
          totalAmountCents: 10000, // ₹100.00
          percentages: {'user1': 70.0, 'user2': 30.0},
        );

        expect(result.length, 2);
        expect(result[0].amountCents, 7000); // 70%
        expect(result[1].amountCents, 3000); // 30%

        final total = result.fold<int>(
          0,
          (sum, split) => sum + split.amountCents,
        );
        expect(total, 10000);
      });

      test('should handle rounding and give remainder to last person', () {
        // 33.33% each for 3 people = 99.99%, last gets remainder
        final result = calculator.calculatePercentageSplit(
          sharedExpenseId: 'exp1',
          totalAmountCents: 10000,
          percentages: {'u1': 33.33, 'u2': 33.33, 'u3': 33.34},
        );

        final total = result.fold<int>(
          0,
          (sum, split) => sum + split.amountCents,
        );
        expect(total, 10000);
      });

      test('should throw error if percentages do not sum to 100', () {
        expect(
          () => calculator.calculatePercentageSplit(
            sharedExpenseId: 'exp1',
            totalAmountCents: 10000,
            percentages: {'user1': 50.0, 'user2': 30.0}, // Only 80%
          ),
          throwsArgumentError,
        );
      });
    });

    group('calculateExactSplit', () {
      test('should return empty list for no amounts', () {
        final result = calculator.calculateExactSplit(
          sharedExpenseId: 'exp1',
          totalAmountCents: 10000,
          amounts: {},
        );

        expect(result, isEmpty);
      });

      test('should split by exact amounts', () {
        final result = calculator.calculateExactSplit(
          sharedExpenseId: 'exp1',
          totalAmountCents: 10000,
          amounts: {'user1': 7500, 'user2': 2500},
        );

        expect(result.length, 2);
        expect(result[0].amountCents, 7500);
        expect(result[1].amountCents, 2500);
      });

      test('should throw error if amounts do not sum to total', () {
        expect(
          () => calculator.calculateExactSplit(
            sharedExpenseId: 'exp1',
            totalAmountCents: 10000,
            amounts: {'user1': 6000, 'user2': 3000}, // Only 9000
          ),
          throwsArgumentError,
        );
      });
    });

    group('calculateSharesSplit', () {
      test('should return empty list for no shares', () {
        final result = calculator.calculateSharesSplit(
          sharedExpenseId: 'exp1',
          totalAmountCents: 10000,
          shares: {},
        );

        expect(result, isEmpty);
      });

      test('should return empty list for all zero shares', () {
        final result = calculator.calculateSharesSplit(
          sharedExpenseId: 'exp1',
          totalAmountCents: 10000,
          shares: {'user1': 0, 'user2': 0},
        );

        expect(result, isEmpty);
      });

      test('should split proportionally by shares', () {
        // user1 has 2 shares, user2 has 1 share = 2:1 ratio
        final result = calculator.calculateSharesSplit(
          sharedExpenseId: 'exp1',
          totalAmountCents: 9000, // ₹90.00
          shares: {'user1': 2, 'user2': 1},
        );

        expect(result.length, 2);
        expect(result[0].amountCents, 6000); // 2/3 of 9000
        expect(result[1].amountCents, 3000); // 1/3 of 9000

        final total = result.fold<int>(
          0,
          (sum, split) => sum + split.amountCents,
        );
        expect(total, 9000);
      });

      test('should handle uneven division with remainder to last', () {
        // 10000 / 3 shares = 3333.33... each
        final result = calculator.calculateSharesSplit(
          sharedExpenseId: 'exp1',
          totalAmountCents: 10000,
          shares: {'u1': 1, 'u2': 1, 'u3': 1},
        );

        final total = result.fold<int>(
          0,
          (sum, split) => sum + split.amountCents,
        );
        expect(total, 10000);
      });

      test('should throw error for negative shares', () {
        expect(
          () => calculator.calculateSharesSplit(
            sharedExpenseId: 'exp1',
            totalAmountCents: 10000,
            shares: {'user1': 2, 'user2': -1},
          ),
          throwsArgumentError,
        );
      });
    });

    group('validateSplit', () {
      test('should return true when splits sum to total', () {
        final splits = calculator.calculateEqualSplit(
          sharedExpenseId: 'exp1',
          totalAmountCents: 10000,
          participantIds: ['user1', 'user2', 'user3'],
        );

        final isValid = calculator.validateSplit(10000, splits);

        expect(isValid, true);
      });

      test('should return false when splits do not sum to total', () {
        final splits = calculator.calculateEqualSplit(
          sharedExpenseId: 'exp1',
          totalAmountCents: 10000,
          participantIds: ['user1', 'user2'],
        );

        // Wrong total
        final isValid = calculator.validateSplit(9999, splits);

        expect(isValid, false);
      });
    });
  });
}
