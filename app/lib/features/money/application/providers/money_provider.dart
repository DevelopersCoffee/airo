import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/utils/locale_settings.dart';
// ignore: unused_import
import '../../../../core/utils/currency_formatter.dart';
import '../../data/repositories/local_wallet_repository.dart';
import '../../domain/models/money_models.dart';
import '../../domain/models/insight_models.dart';
import '../../domain/repositories/money_repositories.dart';
import '../../domain/repositories/wallet_repository.dart';
import '../services/audit_service.dart';

// Native-only imports - these are only used when not on web
// ignore: unused_import
import '../../../../core/database/app_database.dart'
    if (dart.library.html) '../../../../core/database/app_database_stub.dart';
// ignore: unused_import
import '../../data/repositories/local_budgets_repository.dart'
    if (dart.library.html) '../../data/repositories/local_budgets_repository_stub.dart';
// ignore: unused_import
import '../../data/repositories/local_transactions_repository.dart'
    if (dart.library.html) '../../data/repositories/local_transactions_repository_stub.dart';
// ignore: unused_import
import '../services/expense_service.dart'
    if (dart.library.html) '../services/expense_service_stub.dart';
// ignore: unused_import
import '../services/insights_service.dart'
    if (dart.library.html) '../services/insights_service_stub.dart';
// ignore: unused_import
import '../services/sync_service.dart'
    if (dart.library.html) '../services/sync_service_stub.dart';

// ============================================================================
// FAKE IMPLEMENTATIONS FOR DEVELOPMENT
// ============================================================================

class FakeAccountsRepository implements AccountsRepository {
  final Map<String, MoneyAccount> _accounts = {
    'acc1': MoneyAccount(
      id: 'acc1',
      name: 'Checking',
      type: 'checking',
      currency: 'USD',
      balanceCents: 250000, // $2500.00
      createdAt: DateTime(2024, 1, 1),
    ),
    'acc2': MoneyAccount(
      id: 'acc2',
      name: 'Savings',
      type: 'savings',
      currency: 'USD',
      balanceCents: 500000, // $5000.00
      createdAt: DateTime(2024, 1, 1),
    ),
  };

  @override
  Future<Result<List<MoneyAccount>>> fetchAll() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return Ok(_accounts.values.toList());
  }

  @override
  Future<Result<MoneyAccount>> fetchById(String id) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final account = _accounts[id];
    if (account == null) {
      return Err(Exception('Account not found'), StackTrace.current);
    }
    return Ok(account);
  }

  @override
  Future<Result<MoneyAccount>> create({
    required String name,
    required String type,
    required String currency,
    required int balanceCents,
  }) async {
    final account = MoneyAccount(
      id: 'acc${_accounts.length + 1}',
      name: name,
      type: type,
      currency: currency,
      balanceCents: balanceCents,
      createdAt: DateTime.now(),
    );
    _accounts[account.id] = account;
    return Ok(account);
  }

  @override
  Future<Result<MoneyAccount>> update(MoneyAccount account) async {
    _accounts[account.id] = account;
    return Ok(account);
  }

  @override
  Future<Result<void>> delete(String id) async {
    _accounts.remove(id);
    return const Ok(null);
  }

  @override
  Future<MoneyAccount?> get(String id) async => _accounts[id];

  @override
  Future<void> put(String id, MoneyAccount data) async {
    _accounts[id] = data;
  }

  @override
  Future<List<MoneyAccount>> getAll() async => _accounts.values.toList();

  @override
  Future<bool> exists(String id) async => _accounts.containsKey(id);

  @override
  Future<void> clear() async => _accounts.clear();
}

class FakeTransactionsRepository implements TransactionsRepository {
  final Map<String, Transaction> _transactions = {
    'txn1': Transaction(
      id: 'txn1',
      accountId: 'acc1',
      timestamp: DateTime(2024, 11, 1, 10, 30),
      amountCents: -2500, // -$25.00 expense
      description: 'Coffee',
      category: 'Food & Drink',
      tags: const ['coffee', 'daily'],
      createdAt: DateTime(2024, 11, 1),
    ),
    'txn2': Transaction(
      id: 'txn2',
      accountId: 'acc1',
      timestamp: DateTime(2024, 11, 1, 14, 15),
      amountCents: -5000, // -$50.00 expense
      description: 'Lunch',
      category: 'Food & Drink',
      tags: const ['lunch'],
      createdAt: DateTime(2024, 11, 1),
    ),
  };

  @override
  Future<Result<List<Transaction>>> fetch(FetchTransactionsQuery query) async {
    await Future.delayed(const Duration(milliseconds: 300));
    var results = _transactions.values.toList();

    if (query.accountId != null) {
      results = results.where((t) => t.accountId == query.accountId).toList();
    }
    if (query.category != null) {
      results = results.where((t) => t.category == query.category).toList();
    }

    results.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return Ok(results);
  }

  @override
  Future<Result<Transaction>> fetchById(String id) async {
    final txn = _transactions[id];
    if (txn == null) {
      return Err(Exception('Transaction not found'), StackTrace.current);
    }
    return Ok(txn);
  }

  @override
  Future<Result<Transaction>> create({
    required String accountId,
    required DateTime timestamp,
    required int amountCents,
    required String description,
    required String category,
    List<String> tags = const [],
    String? receiptUrl,
  }) async {
    final txn = Transaction(
      id: 'txn${_transactions.length + 1}',
      accountId: accountId,
      timestamp: timestamp,
      amountCents: amountCents,
      description: description,
      category: category,
      tags: tags,
      receiptUrl: receiptUrl,
      createdAt: DateTime.now(),
    );
    _transactions[txn.id] = txn;
    return Ok(txn);
  }

  @override
  Future<Result<void>> delete(String id) async {
    _transactions.remove(id);
    return const Ok(null);
  }

  @override
  Future<Result<Transaction>> update(Transaction transaction) async {
    _transactions[transaction.id] = transaction;
    return Ok(transaction);
  }

  @override
  Future<Result<List<Transaction>>> getForAccount(String accountId) async {
    final txns = _transactions.values
        .where((t) => t.accountId == accountId)
        .toList();
    return Ok(txns);
  }

  @override
  Future<Result<List<Transaction>>> getByCategory(String category) async {
    final txns = _transactions.values
        .where((t) => t.category == category)
        .toList();
    return Ok(txns);
  }

  @override
  Future<Result<List<Transaction>>> getByTag(String tag) async {
    final txns = _transactions.values
        .where((t) => t.tags.contains(tag))
        .toList();
    return Ok(txns);
  }

  @override
  Future<Transaction?> get(String id) async => _transactions[id];

  @override
  Future<void> put(String id, Transaction data) async {
    _transactions[id] = data;
  }

  @override
  Future<List<Transaction>> getAll() async => _transactions.values.toList();

  @override
  Future<bool> exists(String id) async => _transactions.containsKey(id);

  @override
  Future<void> clear() async => _transactions.clear();
}

class FakeBudgetsRepository implements BudgetsRepository {
  final Map<String, Budget> _budgets = {
    'budget1': Budget(
      id: 'budget1',
      tag: 'Food & Drink',
      limitCents: 50000, // $500.00
      usedCents: 27500, // $275.00
      createdAt: DateTime(2024, 11, 1),
    ),
  };

  @override
  Future<Result<List<Budget>>> fetchAll() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return Ok(_budgets.values.toList());
  }

  @override
  Future<Result<Budget>> fetchById(String id) async {
    final budget = _budgets[id];
    if (budget == null) {
      return Err(Exception('Budget not found'), StackTrace.current);
    }
    return Ok(budget);
  }

  @override
  Future<Result<Budget?>> fetchByTag(String tag) async {
    return Ok(
      _budgets.values.cast<Budget?>().firstWhere(
        (b) => b?.tag == tag,
        orElse: () => null,
      ),
    );
  }

  @override
  Future<Result<Budget>> create({
    required String tag,
    required int limitCents,
  }) async {
    final budget = Budget(
      id: 'budget${_budgets.length + 1}',
      tag: tag,
      limitCents: limitCents,
      usedCents: 0,
      createdAt: DateTime.now(),
    );
    _budgets[budget.id] = budget;
    return Ok(budget);
  }

  @override
  Future<Result<Budget>> update(Budget budget) async {
    _budgets[budget.id] = budget;
    return Ok(budget);
  }

  @override
  Future<Result<void>> delete(String id) async {
    _budgets.remove(id);
    return const Ok(null);
  }

  @override
  Future<Result<Budget>> updateUsage(String id, int usedCents) async {
    final budget = _budgets[id];
    if (budget == null) {
      return Err(Exception('Budget not found'), StackTrace.current);
    }
    final updated = Budget(
      id: budget.id,
      tag: budget.tag,
      limitCents: budget.limitCents,
      usedCents: usedCents,
      createdAt: budget.createdAt,
      updatedAt: DateTime.now(),
    );
    _budgets[id] = updated;
    return Ok(updated);
  }

  @override
  Future<Result<void>> resetMonthlyUsage() async {
    for (final id in _budgets.keys) {
      final budget = _budgets[id]!;
      _budgets[id] = Budget(
        id: budget.id,
        tag: budget.tag,
        limitCents: budget.limitCents,
        usedCents: 0,
        createdAt: budget.createdAt,
        updatedAt: DateTime.now(),
      );
    }
    return const Ok(null);
  }

  @override
  Future<Budget?> get(String id) async => _budgets[id];

  @override
  Future<void> put(String id, Budget data) async {
    _budgets[id] = data;
  }

  @override
  Future<List<Budget>> getAll() async => _budgets.values.toList();

  @override
  Future<bool> exists(String id) async => _budgets.containsKey(id);

  @override
  Future<void> clear() async => _budgets.clear();
}

// ============================================================================
// PROVIDERS
// ============================================================================

/// Database provider - singleton
// Database provider - only used on native platforms
// On web, we use fake repositories instead
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

/// Accounts repository provider (using fake for now)
final accountsRepositoryProvider = Provider<AccountsRepository>((ref) {
  return FakeAccountsRepository();
});

/// Transactions repository provider - uses fake on web, local DB on native
final transactionsRepositoryProvider = Provider<TransactionsRepository>((ref) {
  // On web, use fake repository (no SQLite support)
  if (kIsWeb) {
    return FakeTransactionsRepository();
  }
  // On native platforms, use database-backed repository
  return LocalTransactionsRepository(ref.watch(appDatabaseProvider));
});

/// Budgets repository provider - uses fake on web, local DB on native
final budgetsRepositoryProvider = Provider<BudgetsRepository>((ref) {
  // On web, use fake repository (no SQLite support)
  if (kIsWeb) {
    return FakeBudgetsRepository();
  }
  // On native platforms, use database-backed repository
  return LocalBudgetsRepository(ref.watch(appDatabaseProvider));
});

/// Audit service for logging financial operations
final auditServiceProvider = Provider<AuditService>((ref) {
  // TODO: Get actual user ID from auth provider when available
  return AuditService(userId: 'default_user');
});

/// Expense service for transactional operations
final expenseServiceProvider = Provider<ExpenseService>((ref) {
  // On web, use stub service (stub accepts dynamic parameters)
  if (kIsWeb) {
    return (ExpenseService as dynamic)(null, null, null, null)
        as ExpenseService;
  }
  // On native platforms, use real service with database
  final db = ref.watch(appDatabaseProvider);
  final transactionsRepo = LocalTransactionsRepository(db);
  final budgetsRepo = LocalBudgetsRepository(db);
  final auditService = ref.watch(auditServiceProvider);
  return ExpenseService(db, transactionsRepo, budgetsRepo, auditService);
});

/// All accounts provider
final accountsProvider = FutureProvider<List<MoneyAccount>>((ref) async {
  final repo = ref.watch(accountsRepositoryProvider);
  final result = await repo.fetchAll();
  return result.fold((_, _) => [], (accounts) => accounts);
});

/// Total balance provider
final totalBalanceProvider = FutureProvider<int>((ref) async {
  final accounts = await ref.watch(accountsProvider.future);
  return accounts.fold<int>(0, (sum, acc) => sum + acc.balanceCents);
});

/// Recent transactions provider (stream-backed for reactivity)
final recentTransactionsProvider = FutureProvider<List<Transaction>>((
  ref,
) async {
  final repo = ref.watch(transactionsRepositoryProvider);
  final result = await repo.fetch(const FetchTransactionsQuery(limit: 10));
  return result.fold((_, _) => [], (txns) => txns);
});

/// Stream of recent transactions for reactive UI
final transactionsStreamProvider = StreamProvider<List<Transaction>>((ref) {
  // On web, return empty stream (no SQLite support)
  if (kIsWeb) {
    return Stream.value([]);
  }
  // On native, use database-backed repository
  final db = ref.watch(appDatabaseProvider);
  final repo = LocalTransactionsRepository(db);
  return repo.watchTransactions(limit: 50);
});

// ============================================================================
// PAGINATED TRANSACTIONS PROVIDERS
// ============================================================================

/// Transaction filter state
class TransactionFilter {
  final String? category;
  final DateTime? startDate;
  final DateTime? endDate;

  const TransactionFilter({this.category, this.startDate, this.endDate});

  TransactionFilter copyWith({
    String? category,
    DateTime? startDate,
    DateTime? endDate,
    bool clearCategory = false,
    bool clearStartDate = false,
    bool clearEndDate = false,
  }) {
    return TransactionFilter(
      category: clearCategory ? null : (category ?? this.category),
      startDate: clearStartDate ? null : (startDate ?? this.startDate),
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
    );
  }
}

/// Current transaction filter state
final transactionFilterProvider = StateProvider<TransactionFilter>(
  (ref) => const TransactionFilter(),
);

/// Page size for pagination
const _pageSize = 20;

/// Paginated transactions provider
/// Returns transactions for a specific page with filters applied
final paginatedTransactionsProvider =
    FutureProvider.family<List<Transaction>, int>((ref, page) async {
      final repo = ref.watch(transactionsRepositoryProvider);
      final filter = ref.watch(transactionFilterProvider);

      final query = FetchTransactionsQuery(
        category: filter.category,
        startDate: filter.startDate,
        endDate: filter.endDate,
        limit: _pageSize,
        offset: page * _pageSize,
      );

      final result = await repo.fetch(query);
      return result.fold((_, _) => [], (txns) => txns);
    });

/// Total transaction count for pagination info
final transactionCountProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(transactionsRepositoryProvider);
  final filter = ref.watch(transactionFilterProvider);

  // Fetch all to get count (in production, use COUNT query)
  final query = FetchTransactionsQuery(
    category: filter.category,
    startDate: filter.startDate,
    endDate: filter.endDate,
  );

  final result = await repo.fetch(query);
  return result.fold((_, _) => 0, (txns) => txns.length);
});

/// Available categories for filtering
final availableCategoriesProvider = Provider<List<String>>((ref) {
  return const [
    'Food & Drink',
    'Transportation',
    'Entertainment',
    'Shopping',
    'Bills & Utilities',
    'Healthcare',
    'Education',
    'Other',
  ];
});

/// All budgets provider
final budgetsProvider = FutureProvider<List<Budget>>((ref) async {
  final repo = ref.watch(budgetsRepositoryProvider);
  final result = await repo.fetchAll();
  return result.fold((_, _) => [], (budgets) => budgets);
});

/// Stream of budgets for reactive UI
final budgetsStreamProvider = StreamProvider<List<Budget>>((ref) {
  // On web, return empty stream (no SQLite support)
  if (kIsWeb) {
    return Stream.value([]);
  }
  // On native, use database-backed repository
  final db = ref.watch(appDatabaseProvider);
  final repo = LocalBudgetsRepository(db);
  return repo.watchBudgets();
});

/// Insights service provider
final insightsServiceProvider = Provider<InsightsService>((ref) {
  // On web, use stub service (stub accepts dynamic parameters)
  if (kIsWeb) {
    return InsightsService(
      (LocalTransactionsRepository as dynamic)(null)
          as LocalTransactionsRepository,
      (LocalBudgetsRepository as dynamic)(null) as LocalBudgetsRepository,
    );
  }
  // On native, use real service
  final db = ref.watch(appDatabaseProvider);
  return InsightsService(
    LocalTransactionsRepository(db),
    LocalBudgetsRepository(db),
  );
});

/// Sync service provider
final syncServiceProvider = Provider<SyncService>((ref) {
  // On web, use stub service (stub accepts dynamic parameters)
  if (kIsWeb) {
    final service = SyncService(
      (LocalTransactionsRepository as dynamic)(null)
          as LocalTransactionsRepository,
    );
    ref.onDispose(() => service.dispose());
    return service;
  }
  // On native, use real service
  final db = ref.watch(appDatabaseProvider);
  final service = SyncService(LocalTransactionsRepository(db));
  ref.onDispose(() => service.dispose());
  return service;
});

/// Spending summary provider (current month)
final spendingSummaryProvider = FutureProvider<SpendingSummary>((ref) async {
  final service = ref.watch(insightsServiceProvider);
  return service.getSpendingSummary();
});

/// Budget health provider
final budgetHealthProvider = FutureProvider<BudgetHealth>((ref) async {
  final service = ref.watch(insightsServiceProvider);
  return service.getBudgetHealth();
});

/// Spending trend provider
final spendingTrendProvider = FutureProvider<SpendingTrend>((ref) async {
  final service = ref.watch(insightsServiceProvider);
  return service.getSpendingTrend();
});

/// Sync status stream provider
final syncStatusProvider = StreamProvider<SyncState>((ref) {
  final service = ref.watch(syncServiceProvider);
  return service.syncStatus;
});

/// Money controller provider
final moneyControllerProvider = Provider<MoneyController>((ref) {
  return MoneyController(
    ref.watch(accountsRepositoryProvider),
    ref.watch(transactionsRepositoryProvider),
    ref.watch(budgetsRepositoryProvider),
    ref,
  );
});

// ============================================================================
// CONTROLLER
// ============================================================================

class MoneyController {
  final AccountsRepository _accountsRepo;
  // ignore: unused_field - reserved for future transaction operations
  final TransactionsRepository _transactionsRepo;
  final BudgetsRepository _budgetsRepo;
  final Ref _ref;

  MoneyController(
    this._accountsRepo,
    this._transactionsRepo,
    this._budgetsRepo,
    this._ref,
  );

  Future<void> createAccount({
    required String name,
    required String type,
    required String currency,
    required int balanceCents,
  }) async {
    await _accountsRepo.create(
      name: name,
      type: type,
      currency: currency,
      balanceCents: balanceCents,
    );
    _ref.invalidate(accountsProvider);
    _ref.invalidate(totalBalanceProvider);
  }

  /// Add expense with automatic budget deduction
  Future<SaveExpenseResult?> addExpense({
    required String accountId,
    required DateTime timestamp,
    required int amountCents,
    required String description,
    required String category,
    List<String> tags = const [],
    String? receiptUrl,
  }) async {
    final expenseService = _ref.read(expenseServiceProvider);
    final result = await expenseService.saveExpense(
      accountId: accountId,
      timestamp: timestamp,
      amountCents: amountCents,
      description: description,
      category: category,
      tags: tags,
      receiptUrl: receiptUrl,
    );

    _ref.invalidate(recentTransactionsProvider);
    _ref.invalidate(totalBalanceProvider);
    _ref.invalidate(budgetsProvider);

    return result.getOrNull();
  }

  /// Add income (no budget impact)
  Future<Transaction?> addIncome({
    required String accountId,
    required DateTime timestamp,
    required int amountCents,
    required String description,
    required String category,
    List<String> tags = const [],
  }) async {
    final expenseService = _ref.read(expenseServiceProvider);
    final result = await expenseService.saveIncome(
      accountId: accountId,
      timestamp: timestamp,
      amountCents: amountCents,
      description: description,
      category: category,
      tags: tags,
    );

    _ref.invalidate(recentTransactionsProvider);
    _ref.invalidate(totalBalanceProvider);

    return result.getOrNull();
  }

  /// Legacy method - delegates to addExpense for backward compatibility
  Future<void> addTransaction({
    required String accountId,
    required DateTime timestamp,
    required int amountCents,
    required String description,
    required String category,
    List<String> tags = const [],
  }) async {
    if (amountCents < 0) {
      await addExpense(
        accountId: accountId,
        timestamp: timestamp,
        amountCents: amountCents,
        description: description,
        category: category,
        tags: tags,
      );
    } else {
      await addIncome(
        accountId: accountId,
        timestamp: timestamp,
        amountCents: amountCents,
        description: description,
        category: category,
        tags: tags,
      );
    }
  }

  Future<void> createBudget({
    required String tag,
    required int limitCents,
  }) async {
    await _budgetsRepo.create(tag: tag, limitCents: limitCents);
    _ref.invalidate(budgetsProvider);
  }

  Future<void> updateBudget(Budget budget) async {
    await _budgetsRepo.update(budget);
    _ref.invalidate(budgetsProvider);
  }

  Future<void> deleteBudget(String id) async {
    await _budgetsRepo.delete(id);
    _ref.invalidate(budgetsProvider);
  }
}

// ============================================================================
// WALLET PROVIDERS (Real Repository Implementation)
// ============================================================================

/// Wallet repository provider - uses real local storage
final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  return LocalWalletRepository();
});

/// All wallets provider
final walletsProvider = FutureProvider<List<Wallet>>((ref) async {
  final repo = ref.watch(walletRepositoryProvider);
  final result = await repo.fetchAll();
  return result.fold((_, _) => [], (wallets) => wallets);
});

/// Total wallet balance provider (in cents)
final totalWalletBalanceProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(walletRepositoryProvider);
  final result = await repo.getTotalBalanceCents();
  return result.fold((_, _) => 0, (total) => total);
});

/// Formatted total wallet balance provider
final formattedTotalBalanceProvider = FutureProvider<String>((ref) async {
  final balanceCents = await ref.watch(totalWalletBalanceProvider.future);
  final formatter = ref.watch(currencyFormatterProvider);
  return formatter.formatCents(balanceCents);
});

/// Wallet controller for managing wallet operations
class WalletController {
  final WalletRepository _repo;
  final Ref _ref;

  WalletController(this._repo, this._ref);

  Future<Result<Wallet>> createWallet({
    required String name,
    String? description,
    required int balanceCents,
    required WalletType type,
    required String currency,
    String? bankName,
    String? accountNumber,
  }) async {
    final result = await _repo.create(
      name: name,
      description: description,
      balanceCents: balanceCents,
      type: type,
      currency: currency,
      bankName: bankName,
      accountNumber: accountNumber,
    );
    _ref.invalidate(walletsProvider);
    _ref.invalidate(totalWalletBalanceProvider);
    _ref.invalidate(formattedTotalBalanceProvider);
    return result;
  }

  Future<Result<Wallet>> updateWalletBalance(
    String id,
    int newBalanceCents,
  ) async {
    final result = await _repo.updateBalance(id, newBalanceCents);
    _ref.invalidate(walletsProvider);
    _ref.invalidate(totalWalletBalanceProvider);
    _ref.invalidate(formattedTotalBalanceProvider);
    return result;
  }

  Future<Result<void>> deleteWallet(String id) async {
    final result = await _repo.delete(id);
    _ref.invalidate(walletsProvider);
    _ref.invalidate(totalWalletBalanceProvider);
    _ref.invalidate(formattedTotalBalanceProvider);
    return result;
  }
}

/// Wallet controller provider
final walletControllerProvider = Provider<WalletController>((ref) {
  return WalletController(ref.watch(walletRepositoryProvider), ref);
});
