// Conditional imports for native platforms only
import '../../data/repositories/local_transactions_repository.dart'
    if (dart.library.html) '../../data/repositories/local_transactions_repository_stub.dart';
import '../../data/repositories/local_budgets_repository.dart'
    if (dart.library.html) '../../data/repositories/local_budgets_repository_stub.dart';
import '../../domain/models/money_models.dart';
import '../../domain/models/insight_models.dart';
import '../../domain/repositories/money_repositories.dart';

/// Service for generating spending insights and analytics
class InsightsService {
  final LocalTransactionsRepository _transactionsRepo;
  final LocalBudgetsRepository _budgetsRepo;

  InsightsService(this._transactionsRepo, this._budgetsRepo);

  /// Get spending summary for a date range
  Future<SpendingSummary> getSpendingSummary({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final now = DateTime.now();
    final start = startDate ?? DateTime(now.year, now.month, 1);
    final end = endDate ?? now;

    final result = await _transactionsRepo.fetch(
      FetchTransactionsQuery(startDate: start, endDate: end),
    );

    final transactions = result.getOrNull() ?? [];

    int totalExpenses = 0;
    int totalIncome = 0;
    final categorySpending = <String, int>{};
    final dailySpending = <DateTime, int>{};

    for (final txn in transactions) {
      if (txn.isExpense) {
        totalExpenses += txn.amountCents.abs();

        // Category breakdown
        categorySpending[txn.category] =
            (categorySpending[txn.category] ?? 0) + txn.amountCents.abs();

        // Daily breakdown
        final date = DateTime(
          txn.timestamp.year,
          txn.timestamp.month,
          txn.timestamp.day,
        );
        dailySpending[date] =
            (dailySpending[date] ?? 0) + txn.amountCents.abs();
      } else {
        totalIncome += txn.amountCents;
      }
    }

    // Calculate daily average
    final dayCount = end.difference(start).inDays + 1;
    final dailyAverage = dayCount > 0 ? totalExpenses ~/ dayCount : 0;

    // Get top categories
    final sortedCategories = categorySpending.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topCategories = sortedCategories
        .take(5)
        .map((e) => CategorySpending(category: e.key, amountCents: e.value))
        .toList();

    return SpendingSummary(
      startDate: start,
      endDate: end,
      totalExpenses: totalExpenses,
      totalIncome: totalIncome,
      netChange: totalIncome - totalExpenses,
      transactionCount: transactions.length,
      dailyAverage: dailyAverage,
      topCategories: topCategories,
      dailySpending: dailySpending,
    );
  }

  /// Get budget health overview
  Future<BudgetHealth> getBudgetHealth() async {
    final budgetsResult = await _budgetsRepo.fetchAll();
    final budgets = budgetsResult.getOrNull() ?? [];

    if (budgets.isEmpty) {
      return const BudgetHealth(
        totalBudgets: 0,
        healthyBudgets: 0,
        warningBudgets: 0,
        exceededBudgets: 0,
        overallHealthScore: 100,
        insights: [],
      );
    }

    int healthy = 0;
    int warning = 0;
    int exceeded = 0;
    final insights = <BudgetInsight>[];

    for (final budget in budgets) {
      final percentage = budget.percentageUsed;

      if (budget.isExceeded) {
        exceeded++;
        insights.add(
          BudgetInsight(
            type: InsightType.exceeded,
            message:
                '${budget.tag} budget exceeded by ${_formatCurrency(budget.usedCents - budget.limitCents)}',
            category: budget.tag,
            severity: InsightSeverity.high,
          ),
        );
      } else if (percentage >= 0.8) {
        warning++;
        insights.add(
          BudgetInsight(
            type: InsightType.warning,
            message: '${budget.tag} budget at ${(percentage * 100).toInt()}%',
            category: budget.tag,
            severity: InsightSeverity.medium,
          ),
        );
      } else {
        healthy++;
      }
    }

    // Calculate overall health score (0-100)
    final healthScore = ((healthy * 100 + warning * 50) / budgets.length)
        .round();

    return BudgetHealth(
      totalBudgets: budgets.length,
      healthyBudgets: healthy,
      warningBudgets: warning,
      exceededBudgets: exceeded,
      overallHealthScore: healthScore,
      insights: insights,
    );
  }

  /// Get spending trends (compare with previous period)
  Future<SpendingTrend> getSpendingTrend() async {
    final now = DateTime.now();

    // Current month
    final currentStart = DateTime(now.year, now.month, 1);
    final currentSummary = await getSpendingSummary(
      startDate: currentStart,
      endDate: now,
    );

    // Previous month
    final previousStart = DateTime(now.year, now.month - 1, 1);
    final previousEnd = DateTime(
      now.year,
      now.month,
      0,
    ); // Last day of prev month
    final previousSummary = await getSpendingSummary(
      startDate: previousStart,
      endDate: previousEnd,
    );

    // Calculate change
    final expenseChange = previousSummary.totalExpenses > 0
        ? ((currentSummary.totalExpenses - previousSummary.totalExpenses) /
                  previousSummary.totalExpenses *
                  100)
              .round()
        : 0;

    return SpendingTrend(
      currentPeriod: currentSummary,
      previousPeriod: previousSummary,
      expenseChangePercent: expenseChange,
      isSpendingUp: expenseChange > 0,
    );
  }

  String _formatCurrency(int cents) {
    final dollars = cents.abs() ~/ 100;
    final remaining = cents.abs() % 100;
    return '\$$dollars.${remaining.toString().padLeft(2, '0')}';
  }
}
