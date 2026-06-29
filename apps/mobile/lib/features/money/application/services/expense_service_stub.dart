/// Stub for ExpenseService on web platform
library;

import '../../../../core/utils/result.dart';
import '../../domain/models/money_models.dart';

// Re-export shared types for backward compatibility
export '../../domain/models/money_models.dart'
    show SaveExpenseResult, BudgetDeductionStatus;

/// Stub service for web - uses in-memory storage
class ExpenseService {
  ExpenseService(
    dynamic db,
    dynamic transactionsRepo,
    dynamic budgetsRepo,
    dynamic auditService,
  );

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
    return Ok(
      SaveExpenseResult(
        transaction: transaction,
        budgetStatus: BudgetDeductionStatus.noBudget,
      ),
    );
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
    return Ok(
      Transaction(
        id: 'web_txn_${DateTime.now().millisecondsSinceEpoch}',
        accountId: accountId,
        timestamp: timestamp,
        amountCents: amountCents < 0 ? -amountCents : amountCents,
        description: description,
        category: category,
        tags: tags,
        receiptUrl: receiptUrl,
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<List<Transaction>> getPendingTransactions() async => [];
  Future<void> markTransactionSynced(String id) async {}
}
