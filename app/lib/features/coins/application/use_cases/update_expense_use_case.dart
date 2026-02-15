import '../../domain/entities/transaction.dart';
import '../../domain/repositories/transaction_repository.dart';

/// Result type for use case operations
typedef Result<T> = ({T? data, String? error});

/// Use case for updating an existing expense
///
/// Phase: 1 (Foundation)
/// See: docs/features/coins/DOMAIN_API_CONTRACTS.md
class UpdateExpenseUseCase {
  final TransactionRepository _repository;

  UpdateExpenseUseCase(this._repository);

  /// Execute the use case
  ///
  /// Validates and updates the expense in the repository.
  Future<Result<Transaction>> execute(UpdateExpenseParams params) async {
    // Fetch existing transaction
    final existingResult = await _repository.findById(params.id);
    if (existingResult.error != null) {
      return existingResult;
    }

    final existing = existingResult.data;
    if (existing == null) {
      return (
        data: null,
        error: 'Transaction not found',
      );
    }

    // Validate updated fields
    final description = params.description ?? existing.description;
    if (description.trim().isEmpty) {
      return (
        data: null,
        error: 'Description is required',
      );
    }

    final amountCents = params.amountCents ?? existing.amountCents;
    if (amountCents <= 0) {
      return (
        data: null,
        error: 'Amount must be greater than zero',
      );
    }

    // Create updated transaction
    final updated = Transaction(
      id: existing.id,
      description: description.trim(),
      amountCents: amountCents,
      type: params.type ?? existing.type,
      categoryId: params.categoryId ?? existing.categoryId,
      accountId: params.accountId ?? existing.accountId,
      transactionDate: params.transactionDate ?? existing.transactionDate,
      notes: params.notes ?? existing.notes,
      receiptId: params.receiptId ?? existing.receiptId,
      tags: params.tags ?? existing.tags,
      createdAt: existing.createdAt,
      updatedAt: DateTime.now(),
      isDeleted: existing.isDeleted,
    );

    return _repository.update(updated);
  }
}

/// Parameters for updating an expense
class UpdateExpenseParams {
  final String id;
  final String? description;
  final int? amountCents;
  final TransactionType? type;
  final String? categoryId;
  final String? accountId;
  final DateTime? transactionDate;
  final String? notes;
  final String? receiptId;
  final List<String>? tags;

  const UpdateExpenseParams({
    required this.id,
    this.description,
    this.amountCents,
    this.type,
    this.categoryId,
    this.accountId,
    this.transactionDate,
    this.notes,
    this.receiptId,
    this.tags,
  });
}

