// Conditional imports for native platforms only
import '../../../../core/database/app_database.dart'
    if (dart.library.html) '../../../../core/database/app_database_stub.dart';
import '../../../../core/utils/result.dart';
import '../../data/repositories/local_budgets_repository.dart'
    if (dart.library.html) '../../data/repositories/local_budgets_repository_stub.dart';
import '../../data/repositories/local_transactions_repository.dart'
    if (dart.library.html) '../../data/repositories/local_transactions_repository_stub.dart';
import '../../domain/models/money_models.dart';

/// Service for managing expenses with budget deduction
/// Handles transactional operations for offline-first support
class ExpenseService {
  final AppDatabase _db;
  final LocalTransactionsRepository _transactionsRepo;
  final LocalBudgetsRepository _budgetsRepo;

  ExpenseService(this._db, this._transactionsRepo, this._budgetsRepo);

  /// Save an expense and automatically deduct from matching budget
  /// Uses database transaction to ensure atomicity
  Future<Result<SaveExpenseResult>> saveExpense({
    required String accountId,
    required DateTime timestamp,
    required int amountCents,
    required String description,
    required String category,
    List<String> tags = const [],
    String? receiptUrl,
  }) async {
    try {
      // Ensure amount is negative for expenses
      final expenseAmount = amountCents > 0 ? -amountCents : amountCents;

      // Use database transaction for atomicity
      final result = await _db.transaction(() async {
        // Create the transaction
        final transactionResult = await _transactionsRepo.create(
          accountId: accountId,
          timestamp: timestamp,
          amountCents: expenseAmount,
          description: description,
          category: category,
          tags: tags,
          receiptUrl: receiptUrl,
        );

        if (transactionResult.isErr) {
          throw (transactionResult as Err).error;
        }

        final transaction = (transactionResult as Ok<Transaction>).value;

        // Try to deduct from budget
        final budgetResult = await _budgetsRepo.deductFromBudget(
          category,
          expenseAmount,
        );

        BudgetDeductionStatus budgetStatus;
        Budget? updatedBudget;

        if (budgetResult.isOk && (budgetResult as Ok<bool>).value) {
          // Budget was found and updated
          final fetchResult = await _budgetsRepo.fetchByTag(category);
          updatedBudget = fetchResult.getOrNull();

          if (updatedBudget != null && updatedBudget.isExceeded) {
            budgetStatus = BudgetDeductionStatus.exceededLimit;
          } else {
            budgetStatus = BudgetDeductionStatus.success;
          }
        } else {
          // No budget exists for this category
          budgetStatus = BudgetDeductionStatus.noBudget;
        }

        return SaveExpenseResult(
          transaction: transaction,
          budgetStatus: budgetStatus,
          budget: updatedBudget,
        );
      });

      return Ok(result);
    } catch (e, s) {
      return Err(e, s);
    }
  }

  /// Save income transaction (no budget impact)
  Future<Result<Transaction>> saveIncome({
    required String accountId,
    required DateTime timestamp,
    required int amountCents,
    required String description,
    required String category,
    List<String> tags = const [],
    String? receiptUrl,
  }) async {
    // Ensure amount is positive for income
    final incomeAmount = amountCents < 0 ? -amountCents : amountCents;

    return _transactionsRepo.create(
      accountId: accountId,
      timestamp: timestamp,
      amountCents: incomeAmount,
      description: description,
      category: category,
      tags: tags,
      receiptUrl: receiptUrl,
    );
  }

  /// Get pending transactions for sync (offline-outbox)
  Future<List<Transaction>> getPendingTransactions() {
    return _transactionsRepo.getPendingSync();
  }

  /// Mark transaction as synced after successful cloud sync
  Future<void> markTransactionSynced(String id) {
    return _transactionsRepo.markSynced(id);
  }
}

/// Result of saving an expense
class SaveExpenseResult {
  final Transaction transaction;
  final BudgetDeductionStatus budgetStatus;
  final Budget? budget;

  const SaveExpenseResult({
    required this.transaction,
    required this.budgetStatus,
    this.budget,
  });

  /// Check if budget limit was exceeded
  bool get isBudgetExceeded =>
      budgetStatus == BudgetDeductionStatus.exceededLimit;

  /// Check if there was a matching budget
  bool get hasBudget => budgetStatus != BudgetDeductionStatus.noBudget;
}

/// Status of budget deduction after saving expense
enum BudgetDeductionStatus {
  /// Successfully deducted from budget, within limit
  success,

  /// Successfully deducted, but budget limit exceeded
  exceededLimit,

  /// No budget exists for this category
  noBudget,

  /// Error occurred during deduction
  error,
}
