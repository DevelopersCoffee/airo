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
    // TODO: Implement safe-to-spend calculation
    // 1. Sum all monthly budgets
    // 2. Calculate total spent this month
    // 3. Calculate days remaining in month
    // 4. Divide remaining budget by remaining days
    throw UnimplementedError('calculateSafeToSpend not implemented');
  }

  @override
  BudgetStatus getBudgetStatus({
    required Budget budget,
    required List<Transaction> transactions,
    required DateTime currentDate,
  }) {
    // TODO: Implement budget status calculation
    // 1. Get period dates
    // 2. Filter transactions to this period and category
    // 3. Sum spending
    // 4. Calculate percentages and status
    throw UnimplementedError('getBudgetStatus not implemented');
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
    // TODO: Implement based on budget period type
    // For monthly: start of month to end of month
    // For weekly: start of week to end of week
    throw UnimplementedError('getPeriodDates not implemented');
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

