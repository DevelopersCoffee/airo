/// Stub for ExpenseService on web platform
import '../../../../core/utils/result.dart';
import '../../domain/models/money_models.dart';

/// Stub service for web - uses in-memory storage
class ExpenseService {
  ExpenseService(dynamic db, dynamic transactionsRepo, dynamic budgetsRepo);

  Future<Result<SaveExpenseResult>> saveExpense({
    required String accountId,
    required DateTime timestamp,
    required int amountCents,
    required String description,
    required String category,
    List<String> tags = const [],
    String? receiptUrl,
  }) async {
    final transaction = Transaction(
      id: 'web_txn_${DateTime.now().millisecondsSinceEpoch}',
      accountId: accountId,
      timestamp: timestamp,
      amountCents: amountCents > 0 ? -amountCents : amountCents,
      description: description,
      category: category,
      tags: tags,
      receiptUrl: receiptUrl,
      createdAt: DateTime.now(),
    );
    return Ok(SaveExpenseResult(
      transaction: transaction,
      budgetStatus: BudgetDeductionStatus.noBudget,
    ));
  }

  Future<Result<Transaction>> saveIncome({
    required String accountId,
    required DateTime timestamp,
    required int amountCents,
    required String description,
    required String category,
    List<String> tags = const [],
    String? receiptUrl,
  }) async {
    return Ok(Transaction(
      id: 'web_txn_${DateTime.now().millisecondsSinceEpoch}',
      accountId: accountId,
      timestamp: timestamp,
      amountCents: amountCents < 0 ? -amountCents : amountCents,
      description: description,
      category: category,
      tags: tags,
      receiptUrl: receiptUrl,
      createdAt: DateTime.now(),
    ));
  }

  Future<List<Transaction>> getPendingTransactions() async => [];
  Future<void> markTransactionSynced(String id) async {}
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

  bool get isBudgetExceeded => budgetStatus == BudgetDeductionStatus.exceededLimit;
  bool get hasBudget => budgetStatus != BudgetDeductionStatus.noBudget;
}

enum BudgetDeductionStatus {
  success,
  exceededLimit,
  noBudget,
  error,
}

