import '../../domain/entities/transaction.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../../domain/errors/coins_errors.dart';

/// Result type for use case operations
typedef Result<T> = ({T? data, String? error});

/// Use case for adding a new expense
///
/// Handles validation and business logic for creating transactions.
///
/// Phase: 1 (Foundation)
/// See: docs/features/coins/DOMAIN_API_CONTRACTS.md
class AddExpenseUseCase {
  final TransactionRepository _repository;

  AddExpenseUseCase(this._repository);

  /// Execute the use case
  ///
  /// Validates the expense and creates it in the repository.
  /// Returns the created transaction or an error.
  Future<Result<Transaction>> execute(AddExpenseParams params) async {
    // Validate required fields
    if (params.description.trim().isEmpty) {
      return (
        data: null,
        error: 'Description is required',
      );
    }

    if (params.amountCents <= 0) {
      return (
        data: null,
        error: 'Amount must be greater than zero',
      );
    }

    if (params.categoryId.isEmpty) {
      return (
        data: null,
        error: 'Category is required',
      );
    }

    if (params.accountId.isEmpty) {
      return (
        data: null,
        error: 'Account is required',
      );
    }

    // Create the transaction entity
    final now = DateTime.now();
    final transaction = Transaction(
      id: _generateId(),
      description: params.description.trim(),
      amountCents: params.amountCents,
      type: params.type,
      categoryId: params.categoryId,
      accountId: params.accountId,
      transactionDate: params.transactionDate ?? now,
      notes: params.notes,
      receiptId: params.receiptId,
      tags: params.tags,
      createdAt: now,
      isDeleted: false,
    );

    // Save to repository
    return _repository.create(transaction);
  }

  String _generateId() {
    // TODO: Use UUID package or similar
    return 'txn_${DateTime.now().millisecondsSinceEpoch}';
  }
}

/// Parameters for adding an expense
class AddExpenseParams {
  final String description;
  final int amountCents;
  final TransactionType type;
  final String categoryId;
  final String accountId;
  final DateTime? transactionDate;
  final String? notes;
  final String? receiptId;
  final List<String> tags;

  const AddExpenseParams({
    required this.description,
    required this.amountCents,
    this.type = TransactionType.expense,
    required this.categoryId,
    required this.accountId,
    this.transactionDate,
    this.notes,
    this.receiptId,
    this.tags = const [],
  });
}

