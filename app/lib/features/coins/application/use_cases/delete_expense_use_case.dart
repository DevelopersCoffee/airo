import '../../domain/entities/transaction.dart';
import '../../domain/repositories/transaction_repository.dart';

/// Result type for use case operations
typedef Result<T> = ({T? data, String? error});

/// Use case for deleting an expense
///
/// Supports both soft delete (for undo) and hard delete (permanent).
///
/// Phase: 1 (Foundation)
/// See: docs/features/coins/DOMAIN_API_CONTRACTS.md
class DeleteExpenseUseCase {
  final TransactionRepository _repository;

  DeleteExpenseUseCase(this._repository);

  /// Execute soft delete (can be undone)
  ///
  /// Sets isDeleted = true on the transaction.
  Future<Result<void>> execute(String transactionId) async {
    // Verify transaction exists
    final existingResult = await _repository.findById(transactionId);
    if (existingResult.error != null) {
      return (data: null, error: existingResult.error);
    }

    if (existingResult.data == null) {
      return (data: null, error: 'Transaction not found');
    }

    return _repository.delete(transactionId);
  }

  /// Execute hard delete (permanent, cannot be undone)
  Future<Result<void>> executeHardDelete(String transactionId) async {
    return _repository.hardDelete(transactionId);
  }

  /// Restore a soft-deleted transaction
  Future<Result<Transaction>> restore(String transactionId) async {
    return _repository.restore(transactionId);
  }
}

