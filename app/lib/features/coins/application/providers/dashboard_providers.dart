import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/models/safe_to_spend.dart';
import '../../domain/models/budget_status.dart';
import '../../domain/models/balance_summary.dart';
import 'expense_providers.dart';
import 'budget_providers.dart';
import 'group_providers.dart';
import 'settlement_providers.dart';

/// Dashboard data aggregation model
class DashboardData {
  final SafeToSpend? safeToSpend;
  final List<Transaction> recentExpenses;
  final List<BudgetStatus> budgetStatuses;
  final int totalGroups;
  final int pendingSettlements;
  final int spentTodayCents;
  final int spentThisMonthCents;

  const DashboardData({
    this.safeToSpend,
    this.recentExpenses = const [],
    this.budgetStatuses = const [],
    this.totalGroups = 0,
    this.pendingSettlements = 0,
    this.spentTodayCents = 0,
    this.spentThisMonthCents = 0,
  });
}

/// Main dashboard data provider
///
/// Aggregates all data needed for the Coins dashboard screen.
///
/// Phase: 1 (Foundation)
final dashboardDataProvider = FutureProvider<DashboardData>((ref) async {
  // Fetch all required data in parallel
  final results = await Future.wait([
    // Safe to spend
    ref.watch(safeToSpendProvider.future).catchError((_) => null),
    // Recent expenses
    ref.watch(recentExpensesProvider.future).catchError((_) => <Transaction>[]),
    // Budget statuses
    ref.watch(allBudgetStatusProvider.future).catchError((_) => <BudgetStatus>[]),
    // Groups count
    ref.watch(activeGroupsProvider.future).catchError((_) => []),
    // Pending settlements
    ref.watch(pendingSettlementsProvider.future).catchError((_) => []),
    // Spent today
    ref.watch(spentTodayProvider.future).catchError((_) => 0),
    // Spent this month
    ref.watch(spentThisMonthProvider.future).catchError((_) => 0),
  ]);

  return DashboardData(
    safeToSpend: results[0] as SafeToSpend?,
    recentExpenses: results[1] as List<Transaction>,
    budgetStatuses: results[2] as List<BudgetStatus>,
    totalGroups: (results[3] as List).length,
    pendingSettlements: (results[4] as List).length,
    spentTodayCents: results[5] as int,
    spentThisMonthCents: results[6] as int,
  );
});

/// Force refresh dashboard data
final dashboardRefreshProvider = FutureProvider<void>((ref) async {
  // Invalidate all cached providers to force refresh
  ref.invalidate(safeToSpendProvider);
  ref.invalidate(recentExpensesProvider);
  ref.invalidate(allBudgetStatusProvider);
  ref.invalidate(activeGroupsProvider);
  ref.invalidate(pendingSettlementsProvider);
  ref.invalidate(spentTodayProvider);
  ref.invalidate(spentThisMonthProvider);
});

/// Quick stats for dashboard header
final quickStatsProvider = Provider<QuickStats>((ref) {
  final dashboardAsync = ref.watch(dashboardDataProvider);

  return dashboardAsync.maybeWhen(
    data: (data) => QuickStats(
      safeToSpendCents: data.safeToSpend?.amountCents ?? 0,
      spentTodayCents: data.spentTodayCents,
      pendingSettlements: data.pendingSettlements,
      budgetHealth: _calculateOverallHealth(data.budgetStatuses),
    ),
    orElse: () => const QuickStats(),
  );
});

/// Quick stats model
class QuickStats {
  final int safeToSpendCents;
  final int spentTodayCents;
  final int pendingSettlements;
  final double budgetHealth; // 0-100, higher is better

  const QuickStats({
    this.safeToSpendCents = 0,
    this.spentTodayCents = 0,
    this.pendingSettlements = 0,
    this.budgetHealth = 100,
  });
}

/// Calculate overall budget health from all budgets
double _calculateOverallHealth(List<BudgetStatus> statuses) {
  if (statuses.isEmpty) return 100;

  final totalUsed = statuses.fold<double>(
    0,
    (sum, status) => sum + status.percentUsed,
  );

  final avgUsed = totalUsed / statuses.length;
  return (100 - avgUsed).clamp(0, 100);
}

