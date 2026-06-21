import '../entities/transaction.dart';
import '../models/budget_status.dart';

enum FinanceInsightSeverity { info, success, warning, danger }

class FinanceInsight {
  final String title;
  final String message;
  final String actionLabel;
  final FinanceInsightSeverity severity;

  const FinanceInsight({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.severity,
  });
}

class FinanceInsightService {
  const FinanceInsightService();

  List<FinanceInsight> generate({
    required List<Transaction> recentTransactions,
    required List<BudgetStatus> budgetStatuses,
  }) {
    final recurring = recentTransactions
        .where((transaction) => transaction.tags.contains('recurring'))
        .toList(growable: false);
    if (recurring.isNotEmpty) {
      final transaction = recurring.first;
      return [
        FinanceInsight(
          title: 'Recurring expense detected',
          message:
              '${transaction.description} looks recurring. Track it as a bill to avoid surprises.',
          actionLabel: 'Review subscription',
          severity: FinanceInsightSeverity.info,
        ),
      ];
    }

    final atRiskBudgets =
        budgetStatuses
            .where((status) => status.isOverBudget || status.isWarning)
            .toList(growable: false)
          ..sort((a, b) => b.percentUsed.compareTo(a.percentUsed));
    if (atRiskBudgets.isNotEmpty) {
      final status = atRiskBudgets.first;
      return [
        FinanceInsight(
          title: '${status.budget.displayName} budget needs attention',
          message:
              '${status.percentUsed.round()}% used with ${status.transactionCount} expenses this period.',
          actionLabel: 'Open budget',
          severity: status.isOverBudget
              ? FinanceInsightSeverity.danger
              : FinanceInsightSeverity.warning,
        ),
      ];
    }

    if (recentTransactions.isEmpty) {
      return const [
        FinanceInsight(
          title: 'Start your money baseline',
          message:
              'Add your first expense so AIRO can build spending patterns and budget guidance.',
          actionLabel: 'Add first expense',
          severity: FinanceInsightSeverity.info,
        ),
      ];
    }

    return const [
      FinanceInsight(
        title: 'Budget maintained',
        message:
            'Your current spending is within active budget limits. Keep logging daily.',
        actionLabel: 'View trends',
        severity: FinanceInsightSeverity.success,
      ),
    ];
  }
}
