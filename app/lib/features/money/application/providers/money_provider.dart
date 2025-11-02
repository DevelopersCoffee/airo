import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/result.dart';
import '../../domain/models/money_models.dart';
import '../../domain/repositories/money_repositories.dart';

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

/// Accounts repository provider
final accountsRepositoryProvider = Provider<AccountsRepository>((ref) {
  return FakeAccountsRepository();
});

/// Transactions repository provider
final transactionsRepositoryProvider = Provider<TransactionsRepository>((ref) {
  return FakeTransactionsRepository();
});

/// Budgets repository provider
final budgetsRepositoryProvider = Provider<BudgetsRepository>((ref) {
  return FakeBudgetsRepository();
});

/// All accounts provider
final accountsProvider = FutureProvider<List<MoneyAccount>>((ref) async {
  final repo = ref.watch(accountsRepositoryProvider);
  final result = await repo.fetchAll();
  return result.fold((_, __) => [], (accounts) => accounts);
});

/// Total balance provider
final totalBalanceProvider = FutureProvider<int>((ref) async {
  final accounts = await ref.watch(accountsProvider.future);
  return accounts.fold<int>(0, (sum, acc) => sum + acc.balanceCents);
});

/// Recent transactions provider
final recentTransactionsProvider = FutureProvider<List<Transaction>>((
  ref,
) async {
  final repo = ref.watch(transactionsRepositoryProvider);
  final result = await repo.fetch(const FetchTransactionsQuery());
  return result.fold((_, __) => [], (txns) => txns.take(10).toList());
});

/// All budgets provider
final budgetsProvider = FutureProvider<List<Budget>>((ref) async {
  final repo = ref.watch(budgetsRepositoryProvider);
  final result = await repo.fetchAll();
  return result.fold((_, __) => [], (budgets) => budgets);
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

  Future<void> addTransaction({
    required String accountId,
    required DateTime timestamp,
    required int amountCents,
    required String description,
    required String category,
    List<String> tags = const [],
  }) async {
    await _transactionsRepo.create(
      accountId: accountId,
      timestamp: timestamp,
      amountCents: amountCents,
      description: description,
      category: category,
      tags: tags,
    );
    _ref.invalidate(recentTransactionsProvider);
    _ref.invalidate(totalBalanceProvider);
  }

  Future<void> createBudget({
    required String tag,
    required int limitCents,
  }) async {
    await _budgetsRepo.create(tag: tag, limitCents: limitCents);
    _ref.invalidate(budgetsProvider);
  }
}
