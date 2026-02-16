import 'package:flutter_test/flutter_test.dart';
import 'package:airo_app/features/coins/domain/services/budget_engine.dart';
import 'package:airo_app/features/coins/domain/entities/budget.dart';
import 'package:airo_app/features/coins/domain/entities/transaction.dart';
import 'package:airo_app/features/coins/domain/models/safe_to_spend.dart';

void main() {
  late BudgetEngine engine;

  setUp(() {
    engine = BudgetEngineImpl();
  });

  group('BudgetEngineImpl', () {
    group('getPeriodDates', () {
      test('should return correct dates for daily period', () {
        final budget = _createBudget(BudgetPeriod.daily);
        final currentDate = DateTime(2024, 3, 15, 12, 30);

        final (start, end) = engine.getPeriodDates(budget, currentDate);

        expect(start, DateTime(2024, 3, 15));
        expect(end.day, 15);
        expect(end.hour, 23);
      });

      test('should return correct dates for weekly period', () {
        final budget = _createBudget(BudgetPeriod.weekly);
        // March 15, 2024 is a Friday
        final currentDate = DateTime(2024, 3, 15);

        final (start, end) = engine.getPeriodDates(budget, currentDate);

        // Week should start on Monday (March 11)
        expect(start.weekday, 1); // Monday
        expect(start.day, 11);
      });

      test('should return correct dates for monthly period', () {
        final budget = _createBudget(BudgetPeriod.monthly);
        final currentDate = DateTime(2024, 3, 15);

        final (start, end) = engine.getPeriodDates(budget, currentDate);

        expect(start, DateTime(2024, 3, 1));
        expect(end.day, 31); // March has 31 days
      });

      test('should return correct dates for yearly period', () {
        final budget = _createBudget(BudgetPeriod.yearly);
        final currentDate = DateTime(2024, 6, 15);

        final (start, end) = engine.getPeriodDates(budget, currentDate);

        expect(start, DateTime(2024, 1, 1));
        expect(end.month, 12);
        expect(end.day, 31);
      });
    });

    group('daysRemaining', () {
      test('should calculate days remaining in month', () {
        final budget = _createBudget(BudgetPeriod.monthly);
        // March 15, 2024 - should have 16 days remaining (including today)
        final currentDate = DateTime(2024, 3, 15);

        final days = engine.daysRemaining(budget, currentDate);

        // End of March (31st) minus 15th
        expect(days, 16);
      });
    });

    group('calculateDailyAllowance', () {
      test('should calculate correct daily allowance', () {
        final allowance = engine.calculateDailyAllowance(
          remainingCents: 10000,
          daysRemaining: 10,
        );

        expect(allowance, 1000);
      });

      test('should return 0 when no days remaining', () {
        final allowance = engine.calculateDailyAllowance(
          remainingCents: 10000,
          daysRemaining: 0,
        );

        expect(allowance, 0);
      });

      test('should return 0 when budget is exhausted', () {
        final allowance = engine.calculateDailyAllowance(
          remainingCents: 0,
          daysRemaining: 10,
        );

        expect(allowance, 0);
      });

      test('should return 0 when over budget', () {
        final allowance = engine.calculateDailyAllowance(
          remainingCents: -5000,
          daysRemaining: 10,
        );

        expect(allowance, 0);
      });
    });

    group('getBudgetStatus', () {
      test('should calculate budget status correctly', () {
        final budget = _createBudget(BudgetPeriod.monthly, limitCents: 100000);
        final currentDate = DateTime(2024, 3, 15);
        final transactions = [
          _createTransaction('food', 25000, DateTime(2024, 3, 10)),
          _createTransaction('food', 15000, DateTime(2024, 3, 12)),
        ];

        final status = engine.getBudgetStatus(
          budget: budget,
          transactions: transactions,
          currentDate: currentDate,
        );

        expect(status.spentCents, 40000);
        expect(status.remainingCents, 60000);
        expect(status.percentUsed, 40.0);
        expect(status.isOverBudget, false);
        expect(status.transactionCount, 2);
      });

      test('should filter transactions by category', () {
        final budget = _createBudget(BudgetPeriod.monthly);
        final currentDate = DateTime(2024, 3, 15);
        final transactions = [
          _createTransaction('food', 25000, DateTime(2024, 3, 10)),
          _createTransaction('transport', 15000, DateTime(2024, 3, 12)),
        ];

        final status = engine.getBudgetStatus(
          budget: budget,
          transactions: transactions,
          currentDate: currentDate,
        );

        // Only food category should be counted
        expect(status.spentCents, 25000);
        expect(status.transactionCount, 1);
      });

      test('should detect over budget', () {
        final budget = _createBudget(BudgetPeriod.monthly, limitCents: 30000);
        final currentDate = DateTime(2024, 3, 15);
        final transactions = [
          _createTransaction('food', 35000, DateTime(2024, 3, 10)),
        ];

        final status = engine.getBudgetStatus(
          budget: budget,
          transactions: transactions,
          currentDate: currentDate,
        );

        expect(status.isOverBudget, true);
        expect(status.remainingCents, -5000);
      });
    });

    group('calculateSafeToSpend', () {
      test('should return zero values when no budgets', () async {
        final result = await engine.calculateSafeToSpend(
          budgets: [],
          transactions: [],
          currentDate: DateTime(2024, 3, 15),
        );

        expect(result.amountCents, 0);
        expect(result.monthlyBudgetCents, 0);
        expect(result.health, BudgetHealth.healthy);
      });

      test('should calculate safe to spend correctly', () async {
        final budgets = [
          _createBudget(BudgetPeriod.monthly, limitCents: 100000),
        ];
        final currentDate = DateTime(2024, 3, 15);
        final transactions = [
          _createTransaction('food', 30000, DateTime(2024, 3, 10)),
        ];

        final result = await engine.calculateSafeToSpend(
          budgets: budgets,
          transactions: transactions,
          currentDate: currentDate,
        );

        expect(result.spentThisMonthCents, 30000);
        expect(result.monthlyBudgetCents, 100000);
        expect(result.health, BudgetHealth.healthy);
      });

      test('should show warning health when approaching limit', () async {
        final budgets = [
          _createBudget(BudgetPeriod.monthly, limitCents: 100000),
        ];
        final transactions = [
          _createTransaction('food', 75000, DateTime(2024, 3, 10)),
        ];

        final result = await engine.calculateSafeToSpend(
          budgets: budgets,
          transactions: transactions,
          currentDate: DateTime(2024, 3, 15),
        );

        expect(result.percentUsed, 75.0);
        expect(result.health, BudgetHealth.warning);
      });

      test('should show critical health when near/over limit', () async {
        final budgets = [
          _createBudget(BudgetPeriod.monthly, limitCents: 100000),
        ];
        final transactions = [
          _createTransaction('food', 95000, DateTime(2024, 3, 10)),
        ];

        final result = await engine.calculateSafeToSpend(
          budgets: budgets,
          transactions: transactions,
          currentDate: DateTime(2024, 3, 15),
        );

        expect(result.percentUsed, 95.0);
        expect(result.health, BudgetHealth.critical);
      });
    });
  });
}

Budget _createBudget(BudgetPeriod period, {int limitCents = 50000}) {
  return Budget(
    id: 'budget1',
    categoryId: 'food',
    limitCents: limitCents,
    period: period,
    startDate: DateTime(2024, 1, 1),
    createdAt: DateTime(2024, 1, 1),
  );
}

Transaction _createTransaction(String categoryId, int amount, DateTime date) {
  return Transaction(
    id: 'tx_${date.millisecondsSinceEpoch}',
    description: 'Test expense',
    amountCents: -amount, // Expenses are negative
    type: TransactionType.expense,
    categoryId: categoryId,
    accountId: 'account1',
    transactionDate: date,
    createdAt: date,
  );
}
