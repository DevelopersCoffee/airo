import '../../domain/entities/budget.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/repositories/budget_repository.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../../domain/services/budget_engine.dart';
import '../../domain/models/safe_to_spend.dart';

/// Result type for use case operations
typedef Result<T> = ({T? data, String? error});

/// Use case for calculating safe-to-spend amount
///
/// Core feature: calculates daily spending allowance based on budgets.
///
/// Phase: 1 (Foundation)
/// See: docs/features/coins/ENGINEERING_TICKETS_PHASE_1.md (COINS-016)
class CalculateSafeToSpendUseCase {
  final BudgetRepository _budgetRepository;
  final TransactionRepository _transactionRepository;
  final BudgetEngine _budgetEngine;

  CalculateSafeToSpendUseCase(
    this._budgetRepository,
    this._transactionRepository,
    this._budgetEngine,
  );

  /// Execute the use case
  ///
  /// Calculates how much the user can safely spend today without
  /// exceeding their budgets.
  Future<Result<SafeToSpend>> execute() async {
    final now = DateTime.now();

    // Get all active budgets
    final budgetsResult = await _budgetRepository.findActive();
    if (budgetsResult.error != null) {
      return (data: null, error: budgetsResult.error);
    }

    final budgets = budgetsResult.data ?? [];
    if (budgets.isEmpty) {
      // No budgets set, return unlimited
      return (
        data: SafeToSpend(
          amountCents: 0,
          currencyCode: 'INR',
          hasBudget: false,
          calculatedAt: now,
          message: 'Set up a budget to see safe-to-spend',
        ),
        error: null,
      );
    }

    // Get transactions for this month (for monthly budgets)
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    final transactionsResult = await _transactionRepository.findByDateRange(
      startOfMonth,
      endOfMonth,
    );

    if (transactionsResult.error != null) {
      return (data: null, error: transactionsResult.error);
    }

    final transactions = transactionsResult.data ?? [];

    // Calculate safe to spend
    try {
      final safeToSpend = await _budgetEngine.calculateSafeToSpend(
        budgets: budgets,
        transactions: transactions,
        currentDate: now,
      );
      return (data: safeToSpend, error: null);
    } catch (e) {
      return (data: null, error: 'Failed to calculate safe-to-spend: $e');
    }
  }

  /// Get quick calculation without full budget context
  Future<Result<int>> getQuickSafeToSpend() async {
    final result = await execute();
    if (result.error != null) {
      return (data: null, error: result.error);
    }
    return (data: result.data?.amountCents ?? 0, error: null);
  }
}

