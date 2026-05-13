import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/entities/group.dart';
import '../../domain/entities/settlement.dart';
import '../../domain/models/safe_to_spend.dart';
import '../../domain/models/budget_status.dart';
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
  final safeToSpend = await _nullable(ref.watch(safeToSpendProvider.future));
  final recentExpenses = await _listOrEmpty<Transaction>(
    ref.watch(recentExpensesProvider.future),
  );
  final budgetStatuses = await _listOrEmpty<BudgetStatus>(
    ref.watch(allBudgetStatusProvider.future),
  );
  final groups = await _listOrEmpty<Group>(
    ref.watch(activeGroupsProvider.future),
  );
  final pendingSettlements = await _listOrEmpty<Settlement>(
    ref.watch(pendingSettlementsProvider.future),
  );
  final spentTodayCents = await _valueOr(
    ref.watch(spentTodayProvider.future),
    0,
  );
  final spentThisMonthCents = await _valueOr(
    ref.watch(spentThisMonthProvider.future),
    0,
  );

  return DashboardData(
    safeToSpend: safeToSpend,
    recentExpenses: recentExpenses,
    budgetStatuses: budgetStatuses,
    totalGroups: groups.length,
    pendingSettlements: pendingSettlements.length,
    spentTodayCents: spentTodayCents,
    spentThisMonthCents: spentThisMonthCents,
  );
});

Future<T?> _nullable<T>(Future<T> future) async {
  try {
    return await future;
  } catch (_) {
    return null;
  }
}

Future<List<T>> _listOrEmpty<T>(Future<List<T>> future) async {
  try {
    return await future;
  } catch (_) {
    return <T>[];
  }
}

Future<T> _valueOr<T>(Future<T> future, T fallback) async {
  try {
    return await future;
  } catch (_) {
    return fallback;
  }
}

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
