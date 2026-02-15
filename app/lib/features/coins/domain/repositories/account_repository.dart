import '../entities/account.dart';

/// Result type for repository operations
typedef Result<T> = ({T? data, String? error});

/// Account repository interface
///
/// Defines the contract for account data access operations.
///
/// Phase: 1 (Foundation)
/// See: docs/features/coins/DOMAIN_API_CONTRACTS.md
abstract class AccountRepository {
  /// Find an account by ID
  Future<Result<Account>> findById(String id);

  /// Find all active accounts
  Future<Result<List<Account>>> findActive();

  /// Find all accounts (including archived)
  Future<Result<List<Account>>> findAll();

  /// Find the default account
  Future<Result<Account?>> findDefault();

  /// Create a new account
  Future<Result<Account>> create(Account account);

  /// Update an existing account
  Future<Result<Account>> update(Account account);

  /// Update account balance
  Future<Result<Account>> updateBalance(String id, int balanceCents);

  /// Set an account as default
  Future<Result<void>> setDefault(String id);

  /// Archive an account
  Future<Result<void>> archive(String id);

  /// Restore an archived account
  Future<Result<void>> restore(String id);

  /// Delete an account permanently
  Future<Result<void>> delete(String id);

  /// Watch all active accounts
  Stream<List<Account>> watchActive();

  /// Watch total balance across all accounts
  Stream<int> watchTotalBalance();

  /// Get total balance across all accounts
  Future<Result<int>> getTotalBalance();
}

