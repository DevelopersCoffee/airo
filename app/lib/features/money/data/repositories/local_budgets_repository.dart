import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/utils/result.dart';
import '../../domain/models/money_models.dart';
import '../../domain/repositories/money_repositories.dart';

/// Local database implementation of BudgetsRepository
/// Supports offline-first with sync status tracking
class LocalBudgetsRepository implements BudgetsRepository {
  final AppDatabase _db;
  final Uuid _uuid;

  LocalBudgetsRepository(this._db, [Uuid? uuid]) : _uuid = uuid ?? const Uuid();

  /// Get current period month as YYYYMM integer
  int get _currentPeriodMonth {
    final now = DateTime.now();
    return now.year * 100 + now.month;
  }

  @override
  Future<Result<List<Budget>>> fetchAll() async {
    try {
      final results = await (_db.select(_db.budgetEntries)
        ..where((b) => b.periodMonth.equals(_currentPeriodMonth)))
        .get();
      return Ok(results.map(_mapToBudget).toList());
    } catch (e, s) {
      return Err(e, s);
    }
  }

  @override
  Future<Result<Budget>> fetchById(String id) async {
    try {
      final result = await (_db.select(_db.budgetEntries)
        ..where((b) => b.uuid.equals(id)))
        .getSingleOrNull();

      if (result == null) {
        return Err(Exception('Budget not found'), StackTrace.current);
      }
      return Ok(_mapToBudget(result));
    } catch (e, s) {
      return Err(e, s);
    }
  }

  @override
  Future<Result<Budget?>> fetchByTag(String tag) async {
    try {
      final result = await (_db.select(_db.budgetEntries)
        ..where((b) => b.tag.equals(tag) & b.periodMonth.equals(_currentPeriodMonth)))
        .getSingleOrNull();

      return Ok(result != null ? _mapToBudget(result) : null);
    } catch (e, s) {
      return Err(e, s);
    }
  }

  @override
  Future<Result<Budget>> create({
    required String tag,
    required int limitCents,
  }) async {
    try {
      // Check for duplicate budget in current period
      final existing = await fetchByTag(tag);
      if (existing.isOk && existing.getOrNull() != null) {
        return Err(
          Exception('Budget already exists for category: $tag'),
          StackTrace.current,
        );
      }

      // Validate positive amount
      if (limitCents <= 0) {
        return Err(
          Exception('Budget limit must be positive'),
          StackTrace.current,
        );
      }

      final uuid = _uuid.v4();
      final now = DateTime.now();

      await _db.into(_db.budgetEntries).insert(
        BudgetEntriesCompanion.insert(
          uuid: uuid,
          tag: tag,
          limitCents: limitCents,
          periodMonth: _currentPeriodMonth,
          syncStatus: const Value('pending'),
          createdAt: Value(now),
        ),
      );

      final budget = Budget(
        id: uuid,
        tag: tag,
        limitCents: limitCents,
        usedCents: 0,
        createdAt: now,
      );

      return Ok(budget);
    } catch (e, s) {
      return Err(e, s);
    }
  }

  @override
  Future<Result<Budget>> update(Budget budget) async {
    try {
      final now = DateTime.now();
      await (_db.update(_db.budgetEntries)
        ..where((b) => b.uuid.equals(budget.id)))
        .write(BudgetEntriesCompanion(
          tag: Value(budget.tag),
          limitCents: Value(budget.limitCents),
          usedCents: Value(budget.usedCents),
          syncStatus: const Value('pending'),
          updatedAt: Value(now),
        ));

      return Ok(budget);
    } catch (e, s) {
      return Err(e, s);
    }
  }

  @override
  Future<Result<void>> delete(String id) async {
    try {
      await (_db.delete(_db.budgetEntries)
        ..where((b) => b.uuid.equals(id)))
        .go();
      return const Ok(null);
    } catch (e, s) {
      return Err(e, s);
    }
  }

  @override
  Future<Result<Budget>> updateUsage(String id, int usedCents) async {
    try {
      final now = DateTime.now();
      await (_db.update(_db.budgetEntries)
        ..where((b) => b.uuid.equals(id)))
        .write(BudgetEntriesCompanion(
          usedCents: Value(usedCents),
          syncStatus: const Value('pending'),
          updatedAt: Value(now),
        ));

      return fetchById(id);
    } catch (e, s) {
      return Err(e, s);
    }
  }

  @override
  Future<Result<void>> resetMonthlyUsage() async {
    try {
      await (_db.update(_db.budgetEntries)
        ..where((b) => b.periodMonth.equals(_currentPeriodMonth)))
        .write(BudgetEntriesCompanion(
          usedCents: const Value(0),
          updatedAt: Value(DateTime.now()),
        ));
      return const Ok(null);
    } catch (e, s) {
      return Err(e, s);
    }
  }

  // CacheRepository methods
  @override
  Future<Budget?> get(String id) async {
    final result = await fetchById(id);
    return result.getOrNull();
  }

  @override
  Future<void> put(String id, Budget data) async {
    await update(data);
  }

  @override
  Future<List<Budget>> getAll() async {
    final result = await fetchAll();
    return result.getOrNull() ?? [];
  }

  @override
  Future<bool> exists(String id) async {
    final result = await fetchById(id);
    return result.isOk;
  }

  @override
  Future<void> clear() async {
    await _db.delete(_db.budgetEntries).go();
  }

  /// Watch budgets stream for reactive UI
  Stream<List<Budget>> watchBudgets() {
    return (_db.select(_db.budgetEntries)
      ..where((b) => b.periodMonth.equals(_currentPeriodMonth)))
      .watch()
      .map((entries) => entries.map(_mapToBudget).toList());
  }

  /// Deduct from budget when expense is saved
  /// Returns true if budget was found and updated
  Future<Result<bool>> deductFromBudget(String category, int amountCents) async {
    try {
      // Find budget for this category
      final budgetResult = await fetchByTag(category);
      final budget = budgetResult.getOrNull();

      if (budget == null) {
        return const Ok(false); // No budget for this category
      }

      // Add to used amount (amountCents is negative for expenses)
      final newUsedCents = budget.usedCents + amountCents.abs();
      await updateUsage(budget.id, newUsedCents);

      return const Ok(true);
    } catch (e, s) {
      return Err(e, s);
    }
  }

  Budget _mapToBudget(BudgetEntry entry) {
    return Budget(
      id: entry.uuid,
      tag: entry.tag,
      limitCents: entry.limitCents,
      usedCents: entry.usedCents,
      carryoverCents: entry.carryoverCents,
      recurrence: _parseRecurrence(entry.recurrence),
      carryoverBehavior: _parseCarryoverBehavior(entry.carryoverBehavior),
      createdAt: entry.createdAt,
      updatedAt: entry.updatedAt,
    );
  }

  BudgetRecurrence _parseRecurrence(String value) {
    switch (value) {
      case 'weekly': return BudgetRecurrence.weekly;
      case 'yearly': return BudgetRecurrence.yearly;
      default: return BudgetRecurrence.monthly;
    }
  }

  CarryoverBehavior _parseCarryoverBehavior(String value) {
    switch (value) {
      case 'carryUnused': return CarryoverBehavior.carryUnused;
      case 'carryDeficit': return CarryoverBehavior.carryDeficit;
      case 'carryBoth': return CarryoverBehavior.carryBoth;
      default: return CarryoverBehavior.none;
    }
  }

  /// Process period rollover and calculate carryover amounts
  Future<void> processMonthlyRollover() async {
    final now = DateTime.now();
    final currentPeriod = now.year * 100 + now.month;
    final previousPeriod = now.month == 1
        ? (now.year - 1) * 100 + 12
        : now.year * 100 + (now.month - 1);

    // Get budgets from previous period
    final previousBudgets = await (_db.select(_db.budgetEntries)
      ..where((b) => b.periodMonth.equals(previousPeriod)))
      .get();

    for (final budget in previousBudgets) {
      // Check if budget already exists for current period
      final existing = await (_db.select(_db.budgetEntries)
        ..where((b) => b.tag.equals(budget.tag) & b.periodMonth.equals(currentPeriod)))
        .getSingleOrNull();

      if (existing == null) {
        // Calculate carryover based on behavior
        int carryover = 0;
        final behavior = _parseCarryoverBehavior(budget.carryoverBehavior);
        final remaining = budget.limitCents - budget.usedCents;

        switch (behavior) {
          case CarryoverBehavior.none:
            carryover = 0;
            break;
          case CarryoverBehavior.carryUnused:
            carryover = remaining > 0 ? remaining : 0;
            break;
          case CarryoverBehavior.carryDeficit:
            carryover = remaining < 0 ? remaining : 0;
            break;
          case CarryoverBehavior.carryBoth:
            carryover = remaining;
            break;
        }

        // Create new budget for current period
        await _db.into(_db.budgetEntries).insert(
          BudgetEntriesCompanion.insert(
            uuid: _uuid.v4(),
            tag: budget.tag,
            limitCents: budget.limitCents,
            periodMonth: currentPeriod,
            carryoverCents: Value(carryover),
            recurrence: Value(budget.recurrence),
            carryoverBehavior: Value(budget.carryoverBehavior),
          ),
        );
      }
    }
  }
}

