import 'package:flutter_test/flutter_test.dart';
import 'package:airo_app/features/coins/domain/services/debt_simplifier.dart';
import 'package:airo_app/features/coins/domain/models/debt_entry.dart';

void main() {
  late DebtSimplifier simplifier;

  setUp(() {
    simplifier = DebtSimplifierImpl();
  });

  group('DebtSimplifierImpl', () {
    group('fromNetBalances', () {
      test('should return empty list when all balances are zero', () {
        final balances = {'user1': 0, 'user2': 0, 'user3': 0};

        final result = simplifier.fromNetBalances(balances);

        expect(result, isEmpty);
      });

      test('should handle single debtor and single creditor', () {
        // user1 owes ₹100, user2 is owed ₹100
        final balances = {'user1': -10000, 'user2': 10000};

        final result = simplifier.fromNetBalances(balances);

        expect(result.length, 1);
        expect(result[0].fromUserId, 'user1');
        expect(result[0].toUserId, 'user2');
        expect(result[0].amountCents, 10000);
      });

      test('should simplify A->B->C to A->C', () {
        // A owes ₹100 net, B is even, C is owed ₹100 net
        // This simulates: A paid for B (₹100), B paid for C (₹100)
        final balances = {
          'A': -10000, // A owes ₹100
          'B': 0, // B is even
          'C': 10000, // C is owed ₹100
        };

        final result = simplifier.fromNetBalances(balances);

        expect(result.length, 1);
        expect(result[0].fromUserId, 'A');
        expect(result[0].toUserId, 'C');
        expect(result[0].amountCents, 10000);
      });

      test('should handle multiple debtors and creditors', () {
        // A owes ₹150, B owes ₹50, C is owed ₹100, D is owed ₹100
        final balances = {
          'A': -15000,
          'B': -5000,
          'C': 10000,
          'D': 10000,
        };

        final result = simplifier.fromNetBalances(balances);

        // Should produce minimal transfers
        // A -> C (₹100), A -> D (₹50), B -> D (₹50)
        // or similar combination totaling ₹200
        final totalTransferred =
            result.fold<int>(0, (sum, d) => sum + d.amountCents);
        expect(totalTransferred, 20000);

        // Verify balances net out
        final netted = <String, int>{};
        for (final debt in result) {
          netted[debt.fromUserId] =
              (netted[debt.fromUserId] ?? 0) - debt.amountCents;
          netted[debt.toUserId] =
              (netted[debt.toUserId] ?? 0) + debt.amountCents;
        }
        expect(netted['A'], -15000);
        expect(netted['B'], -5000);
        expect(netted['C']! + netted['D']!, 20000);
      });

      test('should handle equal split among 3 people', () {
        // Classic: A paid ₹300 for 3 people, each owes ₹100
        // A is owed ₹200, B owes ₹100, C owes ₹100
        final balances = {
          'A': 20000,
          'B': -10000,
          'C': -10000,
        };

        final result = simplifier.fromNetBalances(balances);

        expect(result.length, 2);

        // B and C should pay A
        final toA = result.where((d) => d.toUserId == 'A').toList();
        expect(toA.length, 2);

        final totalToA = toA.fold<int>(0, (sum, d) => sum + d.amountCents);
        expect(totalToA, 20000);
      });

      test('should use INR as default currency', () {
        final balances = {'user1': -10000, 'user2': 10000};

        final result = simplifier.fromNetBalances(balances);

        expect(result[0].currencyCode, 'INR');
      });

      test('should use custom currency when provided', () {
        final balances = {'user1': -10000, 'user2': 10000};

        final result =
            simplifier.fromNetBalances(balances, currencyCode: 'USD');

        expect(result[0].currencyCode, 'USD');
      });
    });

    group('simplify', () {
      test('should simplify redundant debts', () {
        final debts = [
          const DebtEntry(
            fromUserId: 'A',
            toUserId: 'B',
            amountCents: 10000,
            currencyCode: 'INR',
          ),
          const DebtEntry(
            fromUserId: 'B',
            toUserId: 'C',
            amountCents: 10000,
            currencyCode: 'INR',
          ),
        ];

        final result = simplifier.simplify(debts);

        // A->B->C should become A->C
        expect(result.length, 1);
        expect(result[0].fromUserId, 'A');
        expect(result[0].toUserId, 'C');
        expect(result[0].amountCents, 10000);
      });
    });
  });
}

