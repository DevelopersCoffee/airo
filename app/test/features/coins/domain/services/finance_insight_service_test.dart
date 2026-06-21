import 'package:airo_app/features/coins/domain/entities/budget.dart';
import 'package:airo_app/features/coins/domain/entities/transaction.dart';
import 'package:airo_app/features/coins/domain/models/budget_status.dart';
import 'package:airo_app/features/coins/domain/services/finance_insight_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FinanceInsightService', () {
    test('guides first-time users toward the activation path', () {
      const service = FinanceInsightService();

      final insights = service.generate(
        recentTransactions: const [],
        budgetStatuses: const [],
      );

      expect(insights.first.title, 'Start your money baseline');
      expect(insights.first.actionLabel, 'Add first expense');
    });

    test('surfaces budget warnings before the user overspends', () {
      const service = FinanceInsightService();

      final insights = service.generate(
        recentTransactions: const [],
        budgetStatuses: [
          BudgetStatus(
            budget: Budget(
              id: 'food_budget',
              name: 'Food',
              categoryId: 'food',
              limitCents: 50000,
              period: BudgetPeriod.monthly,
              startDate: DateTime(2026, 5),
              createdAt: DateTime(2026, 5),
            ),
            spentCents: 43000,
            remainingCents: 7000,
            percentUsed: 86,
            isOverBudget: false,
            isWarning: true,
            transactionCount: 10,
            periodStart: DateTime(2026, 5),
            periodEnd: DateTime(2026, 5, 31),
          ),
        ],
      );

      expect(insights.first.title, 'Food budget needs attention');
      expect(insights.first.severity, FinanceInsightSeverity.warning);
    });

    test('detects recurring expenses from transaction tags', () {
      const service = FinanceInsightService();

      final insights = service.generate(
        budgetStatuses: const [],
        recentTransactions: [
          Transaction(
            id: 'txn_1',
            description: 'Netflix',
            amountCents: -64900,
            type: TransactionType.expense,
            categoryId: 'shopping',
            accountId: 'cash',
            transactionDate: DateTime(2026, 5, 15),
            tags: const ['recurring'],
            createdAt: DateTime(2026, 5, 15),
          ),
        ],
      );

      expect(insights.first.title, 'Recurring expense detected');
      expect(insights.first.message, contains('Netflix'));
    });
  });
}
