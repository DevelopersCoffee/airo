import '../entities/budget.dart';
import '../entities/transaction.dart';
import '../models/safe_to_spend.dart';
import '../models/budget_status.dart';

/// Budget calculation engine interface
///
/// Provides budget-related calculations including safe-to-spend.
///
/// Phase: 1 (Foundation)
/// See: docs/features/coins/ENGINEERING_TICKETS_PHASE_1.md (COINS-016)
abstract class BudgetEngine {
  /// Calculate safe-to-spend amount for today
  ///
  /// Takes into account all active budgets and spending to determine
  /// how much the user can safely spend today without exceeding budgets.
  Future<SafeToSpend> calculateSafeToSpend({
    required List<Budget> budgets,
    required List<Transaction> transactions,
    required DateTime currentDate,
  });

  /// Get budget status for a specific budget
  ///
  /// Calculates spending progress against the budget limit.
  BudgetStatus getBudgetStatus({
    required Budget budget,
    required List<Transaction> transactions,
    required DateTime currentDate,
  });

  /// Calculate days remaining in a budget period
  int daysRemaining(Budget budget, DateTime currentDate);

  /// Get the start and end dates for a budget period
  (DateTime start, DateTime end) getPeriodDates(
    Budget budget,
    DateTime currentDate,
  );

  /// Calculate daily allowance based on remaining budget and days
  int calculateDailyAllowance({
    required int remainingCents,
    required int daysRemaining,
  });
}

/// Default implementation of BudgetEngine
class BudgetEngineImpl implements BudgetEngine {
  @override
  Future<SafeToSpend> calculateSafeToSpend({
    required List<Budget> budgets,
    required List<Transaction> transactions,
    required DateTime currentDate,
  }) async {
    // Filter to active monthly budgets
    final activeBudgets = budgets.where((b) => b.isActive).toList();

    if (activeBudgets.isEmpty) {
      return SafeToSpend(
        amountCents: 0,
        dailyLimitCents: 0,
        spentTodayCents: 0,
        spentThisMonthCents: 0,
        monthlyBudgetCents: 0,
        daysRemaining: 0,
        percentUsed: 0,
        health: BudgetHealth.healthy,
        calculatedAt: currentDate,
      );
    }

    // Sum all monthly budgets
    final monthlyBudgetCents = activeBudgets
        .where((b) => b.period == BudgetPeriod.monthly)
        .fold<int>(0, (sum, b) => sum + b.limitCents);

    // Get start of month
    final startOfMonth = DateTime(currentDate.year, currentDate.month, 1);
    final endOfMonth = DateTime(currentDate.year, currentDate.month + 1, 0);
    final startOfToday = DateTime(
      currentDate.year,
      currentDate.month,
      currentDate.day,
    );

    // Calculate spent this month (only expenses, not income)
    final monthlyExpenses = transactions.where(
      (t) =>
          !t.isDeleted &&
          t.type == TransactionType.expense &&
          t.transactionDate.isAfter(
            startOfMonth.subtract(const Duration(days: 1)),
          ) &&
          t.transactionDate.isBefore(endOfMonth.add(const Duration(days: 1))),
    );

    final spentThisMonthCents = monthlyExpenses.fold<int>(
      0,
      (sum, t) => sum + t.amountCents.abs(),
    );

    // Calculate spent today
    final todayExpenses = monthlyExpenses.where(
      (t) =>
          t.transactionDate.year == currentDate.year &&
          t.transactionDate.month == currentDate.month &&
          t.transactionDate.day == currentDate.day,
    );

    final spentTodayCents = todayExpenses.fold<int>(
      0,
      (sum, t) => sum + t.amountCents.abs(),
    );

    // Calculate days remaining (including today)
    final daysRemainingValue = endOfMonth.difference(startOfToday).inDays + 1;

    // Calculate remaining budget
    final remainingCents = monthlyBudgetCents - spentThisMonthCents;

    // Calculate daily allowance
    final dailyLimitCents = daysRemainingValue > 0
        ? (remainingCents / daysRemainingValue).floor()
        : 0;

    // Safe-to-spend for today
    final safeToSpendCents = dailyLimitCents - spentTodayCents;

    // Calculate percent used
    final percentUsed = monthlyBudgetCents > 0
        ? (spentThisMonthCents / monthlyBudgetCents) * 100
        : 0.0;

    // Determine health
    BudgetHealth health;
    if (percentUsed < 70) {
      health = BudgetHealth.healthy;
    } else if (percentUsed < 90) {
      health = BudgetHealth.warning;
    } else {
      health = BudgetHealth.critical;
    }

    return SafeToSpend(
      amountCents: safeToSpendCents,
      dailyLimitCents: dailyLimitCents,
      spentTodayCents: spentTodayCents,
      spentThisMonthCents: spentThisMonthCents,
      monthlyBudgetCents: monthlyBudgetCents,
      daysRemaining: daysRemainingValue,
      percentUsed: percentUsed,
      health: health,
      calculatedAt: currentDate,
    );
  }

  @override
  BudgetStatus getBudgetStatus({
    required Budget budget,
    required List<Transaction> transactions,
    required DateTime currentDate,
  }) {
    final (periodStart, periodEnd) = getPeriodDates(budget, currentDate);

    // Filter transactions to this period and category
    final periodTransactions = transactions.where(
      (t) =>
          !t.isDeleted &&
          t.categoryId == budget.categoryId &&
          t.type == TransactionType.expense &&
          !t.transactionDate.isBefore(periodStart) &&
          !t.transactionDate.isAfter(periodEnd),
    );

    // Sum spending (absolute value since expenses are negative)
    final spentCents = periodTransactions.fold<int>(
      0,
      (sum, t) => sum + t.amountCents.abs(),
    );

    return BudgetStatus.calculate(
      budget: budget,
      spentCents: spentCents,
      transactionCount: periodTransactions.length,
      periodStart: periodStart,
      periodEnd: periodEnd,
    );
  }

  @override
  int daysRemaining(Budget budget, DateTime currentDate) {
    final (_, end) = getPeriodDates(budget, currentDate);
    return end.difference(currentDate).inDays;
  }

  @override
  (DateTime start, DateTime end) getPeriodDates(
    Budget budget,
    DateTime currentDate,
  ) {
    switch (budget.period) {
      case BudgetPeriod.daily:
        final start = DateTime(
          currentDate.year,
          currentDate.month,
          currentDate.day,
        );
        final end = start
            .add(const Duration(days: 1))
            .subtract(const Duration(milliseconds: 1));
        return (start, end);

      case BudgetPeriod.weekly:
        // Week starts on Monday (weekday 1)
        final weekday = currentDate.weekday;
        final daysToSubtract = weekday - 1; // Monday = 1, so subtract 0
        final start = DateTime(
          currentDate.year,
          currentDate.month,
          currentDate.day - daysToSubtract,
        );
        final end = start
            .add(const Duration(days: 7))
            .subtract(const Duration(milliseconds: 1));
        return (start, end);

      case BudgetPeriod.monthly:
        final start = DateTime(currentDate.year, currentDate.month, 1);
        final end = DateTime(
          currentDate.year,
          currentDate.month + 1,
          0,
          23,
          59,
          59,
        );
        return (start, end);

      case BudgetPeriod.yearly:
        final start = DateTime(currentDate.year, 1, 1);
        final end = DateTime(currentDate.year, 12, 31, 23, 59, 59);
        return (start, end);
    }
  }

  @override
  int calculateDailyAllowance({
    required int remainingCents,
    required int daysRemaining,
  }) {
    if (daysRemaining <= 0) return 0;
    if (remainingCents <= 0) return 0;
    return remainingCents ~/ daysRemaining;
  }
}
