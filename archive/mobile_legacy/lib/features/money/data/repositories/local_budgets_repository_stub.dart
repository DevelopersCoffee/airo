/// Stub for LocalBudgetsRepository on web platform
/// Web uses FakeBudgetsRepository from money_provider.dart instead
library;

import '../../domain/models/money_models.dart';
import '../../domain/repositories/money_repositories.dart';
import '../../../../core/utils/result.dart';

/// Stub class - not actually used on web, but needed for type compatibility
class LocalBudgetsRepository implements BudgetsRepository {
  LocalBudgetsRepository(dynamic db);

  @override
  Future<Result<List<Budget>>> fetchAll() async {
    return const Ok([]);
  }

  @override
  Future<Result<Budget>> fetchById(String id) async {
    return Err(Exception('Not implemented on web'), StackTrace.current);
  }

  @override
  Future<Result<Budget?>> fetchByTag(String tag) async {
    return const Ok(null);
  }

  @override
  Future<Result<Budget>> create({
    required String tag,
    required int limitCents,
  }) async {
    return Err(Exception('Not implemented on web'), StackTrace.current);
  }

  @override
  Future<Result<Budget>> update(Budget budget) async {
    return Err(Exception('Not implemented on web'), StackTrace.current);
  }

  @override
  Future<Result<void>> delete(String id) async {
    return const Ok(null);
  }

  @override
  Future<Budget?> get(String id) async => null;

  @override
  Future<void> put(String id, Budget data) async {}

  @override
  Future<List<Budget>> getAll() async => [];

  @override
  Future<bool> exists(String id) async => false;

  @override
  Future<void> clear() async {}

  /// Watch budgets stream - returns empty stream on web
  Stream<List<Budget>> watchBudgets() {
    return Stream.value([]);
  }

  @override
  Future<Result<Budget>> updateUsage(String id, int usedCents) async {
    return Err(Exception('Not implemented on web'), StackTrace.current);
  }

  @override
  Future<Result<void>> resetMonthlyUsage() async {
    return const Ok(null);
  }

  /// Deduct from budget - stub implementation
  Future<Result<bool>> deductFromBudget(
    String category,
    int amountCents,
  ) async {
    return const Ok(false);
  }
}
