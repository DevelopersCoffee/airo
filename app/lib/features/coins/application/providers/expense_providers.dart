import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/locale_settings.dart';
import '../../../money/application/providers/money_provider.dart';
import '../../domain/entities/account.dart';
import '../../domain/entities/category.dart' as coins;
import '../../domain/entities/transaction.dart';
import '../../domain/repositories/account_repository.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../../domain/services/finance_message_parser.dart';
import '../services/finance_chat_ingestion_service.dart';
import '../use_cases/add_expense_use_case.dart';
import '../../data/repositories/account_repository_impl.dart';
import '../../data/repositories/transaction_repository_impl.dart';
import '../../data/datasources/coins_local_datasource_impl_stub.dart'
    if (dart.library.io) '../../data/datasources/coins_local_datasource_impl.dart';
import '../../data/mappers/account_mapper.dart';
import '../../data/mappers/transaction_mapper.dart';

/// Coins local datasource provider - singleton
final coinsLocalDatasourceProvider = Provider<CoinsLocalDatasourceImpl>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return CoinsLocalDatasourceImpl(db);
});

/// Transaction repository provider
///
/// Uses local datasource for offline-first storage.
/// On web, throws UnimplementedError (no SQLite support).
///
/// Phase: 1 (Foundation)
/// See: docs/features/coins/PROJECT_STRUCTURE.md
final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  if (kIsWeb) {
    throw UnimplementedError('Coins feature not supported on web (no SQLite)');
  }
  final datasource = ref.watch(coinsLocalDatasourceProvider);
  return TransactionRepositoryImpl(datasource, TransactionMapper());
});

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  if (kIsWeb) {
    throw UnimplementedError('Coins feature not supported on web (no SQLite)');
  }
  final datasource = ref.watch(coinsLocalDatasourceProvider);
  return AccountRepositoryImpl(datasource, AccountMapper());
});

final expenseCategoryOptionsProvider = Provider<List<coins.Category>>((ref) {
  final now = DateTime(2026);
  return [
    coins.Category(
      id: 'food',
      name: 'Food',
      type: coins.CategoryType.expense,
      iconName: 'restaurant',
      color: '#16A34A',
      isSystem: true,
      sortOrder: 1,
      createdAt: now,
    ),
    coins.Category(
      id: 'transport',
      name: 'Transport',
      type: coins.CategoryType.expense,
      iconName: 'directions_car',
      color: '#2563EB',
      isSystem: true,
      sortOrder: 2,
      createdAt: now,
    ),
    coins.Category(
      id: 'shopping',
      name: 'Shopping',
      type: coins.CategoryType.expense,
      iconName: 'shopping_bag',
      color: '#9333EA',
      isSystem: true,
      sortOrder: 3,
      createdAt: now,
    ),
    coins.Category(
      id: 'salary',
      name: 'Salary',
      type: coins.CategoryType.income,
      iconName: 'payments',
      color: '#0F766E',
      isSystem: true,
      sortOrder: 4,
      createdAt: now,
    ),
  ];
});

final expenseAccountOptionsProvider = FutureProvider<List<Account>>((
  ref,
) async {
  try {
    final repo = ref.watch(accountRepositoryProvider);
    final result = await repo.findActive();
    final accounts = result.data ?? [];
    if (accounts.isNotEmpty) return accounts;
  } catch (_) {
    // Use a first-run fallback when the local account store is not ready.
  }

  final currencyCode = ref.watch(currencyFormatterProvider).currency.code;
  return [
    Account(
      id: 'cash_default',
      name: 'Cash',
      type: AccountType.cash,
      balanceCents: 0,
      currencyCode: currencyCode,
      isDefault: true,
      createdAt: DateTime.now(),
    ),
  ];
});

final addExpenseUseCaseProvider = Provider<AddExpenseUseCase>((ref) {
  return AddExpenseUseCase(ref.watch(transactionRepositoryProvider));
});

final financeMessageParserProvider = Provider<FinanceMessageParser>((ref) {
  return const FinanceMessageParser();
});

final financeChatIngestionServiceProvider =
    Provider<FinanceChatIngestionService>((ref) {
      return FinanceChatIngestionService(
        parser: ref.watch(financeMessageParserProvider),
        repository: ref.watch(transactionRepositoryProvider),
      );
    });

/// Watch all transactions stream
final allExpensesProvider = StreamProvider<List<Transaction>>((ref) {
  final repo = ref.watch(transactionRepositoryProvider);
  return repo.watchAll();
});

/// Watch recent transactions (last 10)
final recentExpensesProvider = FutureProvider<List<Transaction>>((ref) async {
  final repo = ref.watch(transactionRepositoryProvider);
  final result = await repo.findRecent(limit: 10);
  if (result.error != null) {
    throw Exception(result.error);
  }
  return result.data ?? [];
});

/// Watch transactions for today
final todayExpensesProvider = StreamProvider<List<Transaction>>((ref) {
  final repo = ref.watch(transactionRepositoryProvider);
  final today = DateTime.now();
  return repo.watchByDate(today);
});

/// Watch transactions by category
final expensesByCategoryProvider =
    StreamProvider.family<List<Transaction>, String>((ref, categoryId) {
      final repo = ref.watch(transactionRepositoryProvider);
      return repo.watchByCategory(categoryId);
    });

/// Total spent today
final spentTodayProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(transactionRepositoryProvider);
  final now = DateTime.now();
  final startOfDay = DateTime(now.year, now.month, now.day);
  final endOfDay = startOfDay.add(const Duration(days: 1));
  final result = await repo.getTotalSpent(startOfDay, endOfDay);
  return result.data ?? 0;
});

/// Total spent this month
final spentThisMonthProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(transactionRepositoryProvider);
  final now = DateTime.now();
  final startOfMonth = DateTime(now.year, now.month, 1);
  final endOfMonth = DateTime(now.year, now.month + 1, 0);
  final result = await repo.getTotalSpent(startOfMonth, endOfMonth);
  return result.data ?? 0;
});

/// Spending by category for current month
final monthlySpendingByCategoryProvider = FutureProvider<Map<String, int>>((
  ref,
) async {
  final repo = ref.watch(transactionRepositoryProvider);
  final now = DateTime.now();
  final startOfMonth = DateTime(now.year, now.month, 1);
  final endOfMonth = DateTime(now.year, now.month + 1, 0);
  final result = await repo.getSpentByCategory(startOfMonth, endOfMonth);
  return result.data ?? {};
});

/// Search transactions
final expenseSearchProvider = FutureProvider.family<List<Transaction>, String>((
  ref,
  query,
) async {
  if (query.isEmpty) return [];
  final repo = ref.watch(transactionRepositoryProvider);
  final result = await repo.search(query);
  return result.data ?? [];
});

/// Add expense state notifier
final addExpenseProvider =
    StateNotifierProvider.autoDispose<AddExpenseNotifier, AsyncValue<void>>(
      (ref) => AddExpenseNotifier(ref),
    );

class AddExpenseNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  AddExpenseNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<void> addExpense(Transaction expense) async {
    state = const AsyncValue.loading();
    try {
      final repo = _ref.read(transactionRepositoryProvider);
      final result = await repo.create(expense);
      if (result.error != null) {
        state = AsyncValue.error(result.error!, StackTrace.current);
      } else {
        state = const AsyncValue.data(null);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addExpenseFromInput(AddExpenseParams params) async {
    state = const AsyncValue.loading();
    try {
      final result = await _ref.read(addExpenseUseCaseProvider).execute(params);
      if (result.error != null) {
        state = AsyncValue.error(result.error!, StackTrace.current);
        return;
      }
      _ref.invalidate(allExpensesProvider);
      _ref.invalidate(recentExpensesProvider);
      _ref.invalidate(spentTodayProvider);
      _ref.invalidate(spentThisMonthProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
