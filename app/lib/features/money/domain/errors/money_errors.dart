/// Base class for money-related errors
sealed class MoneyError implements Exception {
  final String message;
  final Object? cause;

  const MoneyError(this.message, [this.cause]);

  @override
  String toString() =>
      'MoneyError: $message${cause != null ? ' (caused by: $cause)' : ''}';
}

/// Error when a transaction cannot be found
class TransactionNotFoundError extends MoneyError {
  final String transactionId;

  const TransactionNotFoundError(this.transactionId)
    : super('Transaction not found: $transactionId');
}

/// Error when a budget cannot be found
class BudgetNotFoundError extends MoneyError {
  final String budgetId;

  const BudgetNotFoundError(this.budgetId)
    : super('Budget not found: $budgetId');
}

/// Error when trying to create a duplicate budget for a category
class DuplicateBudgetError extends MoneyError {
  final String category;

  const DuplicateBudgetError(this.category)
    : super('Budget already exists for category: $category');
}

/// Error when validation fails
class ValidationError extends MoneyError {
  final String field;

  const ValidationError(this.field, String message)
    : super('Validation failed for $field: $message');
}

/// Error when database operation fails
class DatabaseError extends MoneyError {
  const DatabaseError(String message, [Object? cause]) : super(message, cause);
}

/// Error when sync operation fails
class SyncError extends MoneyError {
  final String transactionId;

  const SyncError(this.transactionId, String message)
    : super('Sync failed for $transactionId: $message');
}
