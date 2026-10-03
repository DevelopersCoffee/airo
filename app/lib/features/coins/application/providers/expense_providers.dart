import 'package:feature_coins_core/feature_coins_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../../../core/utils/locale_settings.dart';
import '../../../money/application/providers/money_provider.dart';
import '../../domain/entities/category.dart' as coins;
import '../../data/datasources/coins_local_datasource_impl_stub.dart'
    if (dart.library.io) '../../data/datasources/coins_local_datasource_impl.dart';

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
  final quickCapture = NfcQuickExpenseCategories.asCategoryEntities();
  final now = DateTime(2026);
  return [
    ...quickCapture,
    coins.Category(
      id: 'salary',
      name: 'Salary',
      type: coins.CategoryType.income,
      iconName: 'payments',
      color: '#0F766E',
      isSystem: true,
      sortOrder: quickCapture.length + 1,
      createdAt: now,
    ),
  ];
});

final nfcQuickExpenseCaptureServiceProvider =
    Provider<NfcQuickExpenseCaptureService>(
      (ref) => const NfcQuickExpenseCaptureService(),
    );

final completeNfcQuickExpenseCaptureUseCaseProvider =
    Provider<CompleteNfcQuickExpenseCaptureUseCase>((ref) {
      return CompleteNfcQuickExpenseCaptureUseCase(
        ref.watch(addExpenseUseCaseProvider),
        captureService: ref.watch(nfcQuickExpenseCaptureServiceProvider),
      );
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

final transactionReviewServiceProvider = Provider<TransactionReviewService>((
  ref,
) {
  return TransactionReviewService(
    repository: ref.watch(transactionRepositoryProvider),
  );
});

final pendingTransactionReviewsProvider = FutureProvider<List<Transaction>>((
  ref,
) async {
  final result = await ref
      .watch(transactionReviewServiceProvider)
      .pendingImportedTransactions();
  if (result.error != null) {
    throw Exception(result.error);
  }
  return result.data ?? const <Transaction>[];
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
