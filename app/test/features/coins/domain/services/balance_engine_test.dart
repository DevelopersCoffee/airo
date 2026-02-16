import 'package:flutter_test/flutter_test.dart';
import 'package:airo_app/features/coins/domain/services/balance_engine.dart';
import 'package:airo_app/features/coins/domain/entities/shared_expense.dart';
import 'package:airo_app/features/coins/domain/entities/split_entry.dart';
import 'package:airo_app/features/coins/domain/entities/settlement.dart';

void main() {
  late BalanceEngine engine;

  setUp(() {
    engine = BalanceEngineImpl();
  });

  group('BalanceEngineImpl', () {
    group('calculateNetBalances', () {
      test('should return empty map for no expenses', () async {
        final result = await engine.calculateNetBalances(
          expenses: [],
          settlements: [],
        );

        expect(result, isEmpty);
      });

      test('should calculate balance for simple expense', () async {
        // User A paid ₹100 for users A, B, C (equal split)
        final now = DateTime.now();
        final expense = SharedExpense(
          id: 'exp1',
          groupId: 'group1',
          description: 'Lunch',
          totalAmountCents: 10000,
          currencyCode: 'INR',
          categoryId: 'food',
          paidByUserId: 'userA',
          splitType: SplitType.equal,
          splits: [
            _createSplit('userA', 3334),
            _createSplit('userB', 3333),
            _createSplit('userC', 3333),
          ],
          expenseDate: now,
          createdAt: now,
        );

        final result = await engine.calculateNetBalances(
          expenses: [expense],
          settlements: [],
        );

        // A paid 10000, owes 3334 -> net +6666
        // B owes 3333 -> net -3333
        // C owes 3333 -> net -3333
        expect(result['userA'], 6666);
        expect(result['userB'], -3333);
        expect(result['userC'], -3333);

        // Sum should be zero
        final total = result.values.fold<int>(0, (sum, v) => sum + v);
        expect(total, 0);
      });

      test('should handle settlements', () async {
        final now = DateTime.now();
        final expense = SharedExpense(
          id: 'exp1',
          groupId: 'group1',
          description: 'Dinner',
          totalAmountCents: 10000,
          currencyCode: 'INR',
          categoryId: 'food',
          paidByUserId: 'userA',
          splitType: SplitType.equal,
          splits: [_createSplit('userA', 5000), _createSplit('userB', 5000)],
          expenseDate: now,
          createdAt: now,
        );

        // B settles with A
        final settlement = Settlement(
          id: 'set1',
          groupId: 'group1',
          fromUserId: 'userB',
          toUserId: 'userA',
          amountCents: 5000,
          currencyCode: 'INR',
          status: SettlementStatus.completed,
          settlementDate: now,
          createdAt: now,
        );

        final result = await engine.calculateNetBalances(
          expenses: [expense],
          settlements: [settlement],
        );

        // After expense: A +5000, B -5000
        // After settlement: B pays A 5000
        // Final: A +5000 - 5000 = 0, B -5000 + 5000 = 0
        expect(result['userA'], 0);
        expect(result['userB'], 0);
      });

      test('should skip deleted expenses', () async {
        final now = DateTime.now();
        final expense = SharedExpense(
          id: 'exp1',
          groupId: 'group1',
          description: 'Deleted',
          totalAmountCents: 10000,
          currencyCode: 'INR',
          categoryId: 'food',
          paidByUserId: 'userA',
          splitType: SplitType.equal,
          splits: [_createSplit('userA', 5000), _createSplit('userB', 5000)],
          expenseDate: now,
          createdAt: now,
          isDeleted: true,
        );

        final result = await engine.calculateNetBalances(
          expenses: [expense],
          settlements: [],
        );

        expect(result, isEmpty);
      });

      test('should skip pending settlements', () async {
        final now = DateTime.now();
        final expense = SharedExpense(
          id: 'exp1',
          groupId: 'group1',
          description: 'Dinner',
          totalAmountCents: 10000,
          currencyCode: 'INR',
          categoryId: 'food',
          paidByUserId: 'userA',
          splitType: SplitType.equal,
          splits: [_createSplit('userA', 5000), _createSplit('userB', 5000)],
          expenseDate: now,
          createdAt: now,
        );

        final settlement = Settlement(
          id: 'set1',
          groupId: 'group1',
          fromUserId: 'userB',
          toUserId: 'userA',
          amountCents: 5000,
          currencyCode: 'INR',
          status: SettlementStatus.pending, // Not completed
          settlementDate: now,
          createdAt: now,
        );

        final result = await engine.calculateNetBalances(
          expenses: [expense],
          settlements: [settlement],
        );

        // Settlement is pending, so balances should not be affected
        expect(result['userA'], 5000);
        expect(result['userB'], -5000);
      });
    });

    group('getUserBalance', () {
      test('should return 0 for unknown user', () {
        final balances = {'userA': 5000, 'userB': -5000};

        final result = engine.getUserBalance('userC', balances);

        expect(result, 0);
      });

      test('should return correct balance for known user', () {
        final balances = {'userA': 5000, 'userB': -3000};

        expect(engine.getUserBalance('userA', balances), 5000);
        expect(engine.getUserBalance('userB', balances), -3000);
      });
    });
  });
}

SplitEntry _createSplit(String userId, int amountCents) {
  return SplitEntry(
    id: 'split_$userId',
    sharedExpenseId: 'exp1',
    userId: userId,
    amountCents: amountCents,
    createdAt: DateTime.now(),
  );
}
