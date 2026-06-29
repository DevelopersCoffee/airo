import '../../../../core/domain/repository.dart';
import '../../../../core/utils/result.dart';
import '../models/money_models.dart';

/// Query for fetching accounts
class FetchAccountsQuery {
  final String? currency;
  final String? type;

  const FetchAccountsQuery({this.currency, this.type});
}

/// Accounts repository interface
abstract interface class AccountsRepository
    implements CacheRepository<String, MoneyAccount> {
  /// Fetch all accounts
  Future<Result<List<MoneyAccount>>> fetchAll();

  /// Fetch account by ID
  Future<Result<MoneyAccount>> fetchById(String id);

  /// Create new account
  Future<Result<MoneyAccount>> create({
    required String name,
    required String type,
    required String currency,
    required int balanceCents,
  });

  /// Update account
  Future<Result<MoneyAccount>> update(MoneyAccount account);

  /// Delete account
  @override
  Future<Result<void>> delete(String id);
}

/// Query for fetching transactions
class FetchTransactionsQuery {
  final String? accountId;
  final String? category;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<String>? tags;
  final int? limit;
  final int? offset;

  const FetchTransactionsQuery({
    this.accountId,
    this.category,
    this.startDate,
    this.endDate,
    this.tags,
    this.limit,
    this.offset,
  });
}

/// Transactions repository interface
abstract interface class TransactionsRepository
    implements CacheRepository<String, Transaction> {
  /// Fetch transactions with query
  Future<Result<List<Transaction>>> fetch(FetchTransactionsQuery query);

  /// Fetch transaction by ID
  Future<Result<Transaction>> fetchById(String id);

  /// Create new transaction
  Future<Result<Transaction>> create({
    required String accountId,
    required DateTime timestamp,
    required int amountCents,
    required String description,
    required String category,
    List<String> tags = const [],
    String? receiptUrl,
  });

  /// Update transaction
  Future<Result<Transaction>> update(Transaction transaction);

  /// Delete transaction
  @override
  Future<Result<void>> delete(String id);

  /// Get transactions for account
  Future<Result<List<Transaction>>> getForAccount(String accountId);

  /// Get transactions by category
  Future<Result<List<Transaction>>> getByCategory(String category);

  /// Get transactions by tag
  Future<Result<List<Transaction>>> getByTag(String tag);
}

/// Budgets repository interface
abstract interface class BudgetsRepository
    implements CacheRepository<String, Budget> {
  /// Fetch all budgets
  Future<Result<List<Budget>>> fetchAll();

  /// Fetch budget by ID
  Future<Result<Budget>> fetchById(String id);

  /// Fetch budget by tag
  Future<Result<Budget?>> fetchByTag(String tag);

  /// Create new budget
  Future<Result<Budget>> create({required String tag, required int limitCents});

  /// Update budget
  Future<Result<Budget>> update(Budget budget);

  /// Delete budget
  @override
  Future<Result<void>> delete(String id);

  /// Update budget usage
  Future<Result<Budget>> updateUsage(String id, int usedCents);

  /// Reset budget usage (monthly)
  Future<Result<void>> resetMonthlyUsage();
}

/// Money insights repository interface
abstract interface class InsightsRepository {
  /// Get insights
  Future<Result<List<MoneyInsight>>> getInsights();

  /// Get spending trends
  Future<Result<List<MoneyInsight>>> getSpendingTrends();

  /// Get budget alerts
  Future<Result<List<MoneyInsight>>> getBudgetAlerts();

  /// Get savings goals
  Future<Result<List<MoneyInsight>>> getSavingsGoals();
}
