import 'package:airo_app/features/coins/domain/entities/budget.dart';
import 'package:airo_app/features/coins/domain/entities/transaction.dart';
import 'package:airo_app/features/coins/domain/models/budget_status.dart';
import 'package:airo_app/features/coins/domain/services/finance_insight_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = FinanceInsightService();

  group('FinanceInsightService', () {
    test('prioritizes recurring charges as subscription review insight', () {
      final insights = service.generate(
        recentTransactions: [
          _transaction(
            description: 'Netflix',
            amountCents: -64900,
            tags: const ['recurring'],
          ),
        ],
        budgetStatuses: const [],
      );

      expect(insights, hasLength(1));
      expect(insights.first.title, 'Recurring expense detected');
      expect(insights.first.message, contains('Netflix'));
      expect(insights.first.actionLabel, 'Review subscription');
      expect(insights.first.severity, FinanceInsightSeverity.info);
    });

    test('flags the highest risk budget when no recurring charge exists', () {
      final insights = service.generate(
        recentTransactions: [_transaction(description: 'Dinner')],
        budgetStatuses: [
          _budgetStatus(name: 'Food', percentUsed: 86, isWarning: true),
          _budgetStatus(
            name: 'Shopping',
            percentUsed: 104,
            isOverBudget: true,
            isWarning: true,
          ),
        ],
      );

      expect(insights, hasLength(1));
      expect(insights.first.title, 'Shopping budget needs attention');
      expect(insights.first.message, contains('104% used'));
      expect(insights.first.severity, FinanceInsightSeverity.danger);
    });

    test('asks for first expense when there is no finance baseline', () {
      final insights = service.generate(
        recentTransactions: const [],
        budgetStatuses: const [],
      );

      expect(insights, hasLength(1));
      expect(insights.first.title, 'Start your money baseline');
      expect(insights.first.actionLabel, 'Add first expense');
    });

    test('reports healthy budget status when spending is in range', () {
      final insights = service.generate(
        recentTransactions: [_transaction(description: 'Groceries')],
        budgetStatuses: [_budgetStatus(name: 'Food', percentUsed: 45)],
      );

      expect(insights, hasLength(1));
      expect(insights.first.title, 'Budget maintained');
      expect(insights.first.severity, FinanceInsightSeverity.success);
    });
  });
}

Transaction _transaction({
  required String description,
  int amountCents = -12000,
  List<String> tags = const [],
}) {
  return Transaction(
    id: description,
    description: description,
    amountCents: amountCents,
    type: TransactionType.expense,
    categoryId: 'food',
    accountId: 'cash',
    transactionDate: DateTime(2026, 5, 19),
    tags: tags,
    createdAt: DateTime(2026, 5, 19),
  );
}

BudgetStatus _budgetStatus({
  required String name,
  required double percentUsed,
  bool isOverBudget = false,
  bool isWarning = false,
}) {
  final budget = Budget(
    id: name,
    name: name,
    categoryId: name.toLowerCase(),
    limitCents: 100000,
    period: BudgetPeriod.monthly,
    startDate: DateTime(2026, 5, 1),
    createdAt: DateTime(2026, 5, 1),
  );

  return BudgetStatus(
    budget: budget,
    spentCents: (100000 * percentUsed / 100).round(),
    remainingCents: 100000 - (100000 * percentUsed / 100).round(),
    percentUsed: percentUsed,
    isOverBudget: isOverBudget,
    isWarning: isWarning,
    transactionCount: 3,
    periodStart: DateTime(2026, 5, 1),
    periodEnd: DateTime(2026, 5, 31),
  );
}
