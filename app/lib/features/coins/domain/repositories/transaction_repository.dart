import '../entities/transaction.dart';

/// Result type for repository operations
/// TODO: Import from core_domain when available
typedef Result<T> = ({T? data, String? error});

/// Transaction repository interface
///
/// Defines the contract for transaction data access operations.
///
/// Phase: 1 (Foundation)
/// See: docs/features/coins/DOMAIN_API_CONTRACTS.md
abstract class TransactionRepository {
  /// Find a transaction by ID
  Future<Result<Transaction>> findById(String id);

  /// Find transactions within a date range
  Future<Result<List<Transaction>>> findByDateRange(
    DateTime start,
    DateTime end,
  );

  /// Find transactions by category
  Future<Result<List<Transaction>>> findByCategory(String categoryId);

  /// Find transactions by account
  Future<Result<List<Transaction>>> findByAccount(String accountId);

  /// Find recent transactions
  Future<Result<List<Transaction>>> findRecent({int limit = 10});

  /// Create a new transaction
  Future<Result<Transaction>> create(Transaction transaction);

  /// Update an existing transaction
  Future<Result<Transaction>> update(Transaction transaction);

  /// Soft delete a transaction (sets isDeleted = true)
  Future<Result<void>> delete(String id);

  /// Permanently delete a transaction
  Future<Result<void>> hardDelete(String id);

  /// Restore a soft-deleted transaction
  Future<Result<Transaction>> restore(String id);

  /// Watch all active transactions (excludes deleted)
  Stream<List<Transaction>> watchAll();

  /// Watch transactions by category
  Stream<List<Transaction>> watchByCategory(String categoryId);

  /// Watch transactions for a specific date
  Stream<List<Transaction>> watchByDate(DateTime date);

  /// Get total spent in a date range
  Future<Result<int>> getTotalSpent(DateTime start, DateTime end);

  /// Get total spent by category in a date range
  Future<Result<Map<String, int>>> getSpentByCategory(
    DateTime start,
    DateTime end,
  );

  /// Search transactions by description
  Future<Result<List<Transaction>>> search(String query);
}

