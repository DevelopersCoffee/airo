/// Stub for InsightsService on web platform
import '../../domain/models/insight_models.dart';

/// Stub service for web - returns empty/default data
class InsightsService {
  InsightsService(dynamic transactionsRepo, dynamic budgetsRepo);

  Future<SpendingSummary> getSpendingSummary({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final now = DateTime.now();
    return SpendingSummary(
      startDate: startDate ?? DateTime(now.year, now.month, 1),
      endDate: endDate ?? now,
      totalExpenses: 0,
      totalIncome: 0,
      netChange: 0,
      transactionCount: 0,
      dailyAverage: 0,
      topCategories: [],
      dailySpending: {},
    );
  }

  Future<BudgetHealth> getBudgetHealth() async {
    return const BudgetHealth(
      totalBudgets: 0,
      healthyBudgets: 0,
      warningBudgets: 0,
      exceededBudgets: 0,
      overallHealthScore: 100,
      insights: [],
    );
  }

  Future<SpendingTrend> getSpendingTrend() async {
    final now = DateTime.now();
    final emptySummary = SpendingSummary(
      startDate: DateTime(now.year, now.month, 1),
      endDate: now,
      totalExpenses: 0,
      totalIncome: 0,
      netChange: 0,
      transactionCount: 0,
      dailyAverage: 0,
      topCategories: [],
      dailySpending: {},
    );
    return SpendingTrend(
      currentPeriod: emptySummary,
      previousPeriod: emptySummary,
      expenseChangePercent: 0,
      isSpendingUp: false,
    );
  }
}
