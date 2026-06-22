import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/budget.dart';
import '../../domain/repositories/budget_repository.dart';
import '../../domain/services/budget_engine.dart';
import '../../domain/models/safe_to_spend.dart';
import '../../domain/models/budget_status.dart';
import '../../data/repositories/budget_repository_impl.dart';
import '../../data/mappers/budget_mapper.dart';
import 'expense_providers.dart';

/// Budget repository provider
///
/// Uses local datasource for offline-first storage.
/// On web, uses an empty repository so the UI can show a planned state instead
/// of leaking SQLite implementation details.
///
/// Phase: 1 (Foundation)
final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  if (kIsWeb) {
    return WebEmptyBudgetRepository();
  }
  final datasource = ref.watch(coinsLocalDatasourceProvider);
  return BudgetRepositoryImpl(datasource, BudgetMapper());
});

class WebEmptyBudgetRepository implements BudgetRepository {
  const WebEmptyBudgetRepository();

  @override
  Future<Result<Budget>> findById(String id) async {
    return (data: null, error: 'Budgets are not saved on web yet.');
  }

  @override
  Future<Result<Budget?>> findByCategory(String categoryId) async {
    return (data: null, error: null);
  }

  @override
  Future<Result<List<Budget>>> findActive() async {
    return (data: const <Budget>[], error: null);
  }

  @override
  Future<Result<List<Budget>>> findAll() async {
    return (data: const <Budget>[], error: null);
  }

  @override
  Future<Result<Budget>> create(Budget budget) async {
    return (data: null, error: 'Budget creation is coming to web.');
  }

  @override
  Future<Result<Budget>> update(Budget budget) async {
    return (data: null, error: 'Budget editing is coming to web.');
  }

  @override
  Future<Result<void>> deactivate(String id) async {
    return (data: null, error: 'Budget editing is coming to web.');
  }

  @override
  Future<Result<void>> delete(String id) async {
    return (data: null, error: 'Budget editing is coming to web.');
  }

  @override
  Stream<List<Budget>> watchActive() {
    return Stream.value(const <Budget>[]);
  }

  @override
  Stream<Budget?> watchById(String id) {
    return Stream.value(null);
  }

  @override
  Future<Result<bool>> hasBudget(String categoryId) async {
    return (data: false, error: null);
  }
}

/// Budget engine provider
final budgetEngineProvider = Provider<BudgetEngine>((ref) {
  return BudgetEngineImpl();
});

/// Watch all active budgets
final activeBudgetsProvider = StreamProvider<List<Budget>>((ref) {
  final repo = ref.watch(budgetRepositoryProvider);
  return repo.watchActive();
});

/// Watch a specific budget by ID
final budgetByIdProvider = StreamProvider.family<Budget?, String>((ref, id) {
  final repo = ref.watch(budgetRepositoryProvider);
  return repo.watchById(id);
});

/// Budget for a specific category
final budgetByCategoryProvider = FutureProvider.family<Budget?, String>((
  ref,
  categoryId,
) async {
  final repo = ref.watch(budgetRepositoryProvider);
  final result = await repo.findByCategory(categoryId);
  return result.data;
});

/// Safe to spend calculation
///
/// Core feature: calculates how much user can spend today
final safeToSpendProvider = FutureProvider<SafeToSpend>((ref) async {
  // TODO: Implement when repositories are ready
  // final budgetRepo = ref.watch(budgetRepositoryProvider);
  // final transactionRepo = ref.watch(transactionRepositoryProvider);
  // final engine = ref.watch(budgetEngineProvider);
  //
  // final budgets = await budgetRepo.findActive();
  // final transactions = await transactionRepo.findByDateRange(...);
  //
  // return engine.calculateSafeToSpend(
  //   budgets: budgets.data ?? [],
  //   transactions: transactions.data ?? [],
  //   currentDate: DateTime.now(),
  // );

  throw UnimplementedError('safeToSpendProvider not yet implemented');
});

/// Budget status for all active budgets
final allBudgetStatusProvider = FutureProvider<List<BudgetStatus>>((ref) async {
  // TODO: Implement when repositories are ready
  throw UnimplementedError('allBudgetStatusProvider not yet implemented');
});

/// Budget status for a specific budget
final budgetStatusProvider = FutureProvider.family<BudgetStatus?, String>((
  ref,
  budgetId,
) async {
  // TODO: Implement when repositories are ready
  throw UnimplementedError('budgetStatusProvider not yet implemented');
});

/// Set/update budget state notifier
final setBudgetProvider =
    StateNotifierProvider.autoDispose<SetBudgetNotifier, AsyncValue<void>>(
      (ref) => SetBudgetNotifier(ref),
    );

class SetBudgetNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  SetBudgetNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<void> setBudget(Budget budget) async {
    state = const AsyncValue.loading();
    try {
      final repo = _ref.read(budgetRepositoryProvider);
      final existing = await repo.findByCategory(budget.categoryId);

      if (existing.data != null) {
        // Update existing budget
        await repo.update(budget);
      } else {
        // Create new budget
        await repo.create(budget);
      }
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deactivateBudget(String budgetId) async {
    state = const AsyncValue.loading();
    try {
      final repo = _ref.read(budgetRepositoryProvider);
      await repo.deactivate(budgetId);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
