import '../entities/budget.dart';

/// Result type for repository operations
typedef Result<T> = ({T? data, String? error});

/// Budget repository interface
///
/// Defines the contract for budget data access operations.
///
/// Phase: 1 (Foundation)
/// See: docs/features/coins/DOMAIN_API_CONTRACTS.md
abstract class BudgetRepository {
  /// Find a budget by ID
  Future<Result<Budget>> findById(String id);

  /// Find budget for a specific category
  Future<Result<Budget?>> findByCategory(String categoryId);

  /// Find all active budgets
  Future<Result<List<Budget>>> findActive();

  /// Find all budgets (including inactive)
  Future<Result<List<Budget>>> findAll();

  /// Create a new budget
  Future<Result<Budget>> create(Budget budget);

  /// Update an existing budget
  Future<Result<Budget>> update(Budget budget);

  /// Deactivate a budget
  Future<Result<void>> deactivate(String id);

  /// Delete a budget permanently
  Future<Result<void>> delete(String id);

  /// Watch all active budgets
  Stream<List<Budget>> watchActive();

  /// Watch a specific budget
  Stream<Budget?> watchById(String id);

  /// Check if a category has an active budget
  Future<Result<bool>> hasBudget(String categoryId);
}

