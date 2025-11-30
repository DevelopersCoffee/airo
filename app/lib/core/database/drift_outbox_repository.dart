import 'package:core_data/core_data.dart';
import 'package:core_domain/core_domain.dart';
import 'package:drift/drift.dart';

import 'app_database.dart';

/// Drift-based implementation of OutboxRepository for persistent sync operations.
class DriftOutboxRepository implements OutboxRepository {
  DriftOutboxRepository(this._db);

  final AppDatabase _db;

  @override
  Future<Result<SyncOperation>> add(SyncOperation operation) async {
    try {
      await _db.into(_db.outboxEntries).insert(
        OutboxEntriesCompanion.insert(
          operationId: operation.id,
          entityType: operation.entityType,
          entityId: operation.entityId,
          operationType: operation.operationType.name,
          payload: operation.payload,
          priority: Value(operation.priority.index),
          status: Value(operation.status.name),
          retryCount: Value(operation.retryCount),
          lastError: Value(operation.lastError),
          createdAt: Value(operation.createdAt),
          lastAttemptAt: Value(operation.lastAttemptAt),
        ),
      );
      return Success(operation);
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to add to outbox: $e'));
    }
  }

  @override
  Future<Result<List<SyncOperation>>> getPending() async {
    try {
      final query = _db.select(_db.outboxEntries)
        ..where((t) => t.status.equals('pending'))
        ..orderBy([
          (t) => OrderingTerm.desc(t.priority),
          (t) => OrderingTerm.asc(t.createdAt),
        ]);

      final rows = await query.get();
      return Success(rows.map(_mapToSyncOperation).toList());
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to get pending: $e'));
    }
  }

  @override
  Future<Result<List<SyncOperation>>> getForEntity(
    String entityType,
    String entityId,
  ) async {
    try {
      final query = _db.select(_db.outboxEntries)
        ..where((t) => t.entityType.equals(entityType) & t.entityId.equals(entityId));

      final rows = await query.get();
      return Success(rows.map(_mapToSyncOperation).toList());
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to get for entity: $e'));
    }
  }

  @override
  Future<Result<SyncOperation>> updateStatus(
    String operationId,
    SyncOperationStatus status, {
    String? error,
  }) async {
    try {
      await (_db.update(_db.outboxEntries)
        ..where((t) => t.operationId.equals(operationId)))
        .write(OutboxEntriesCompanion(
          status: Value(status.name),
          lastError: Value(error),
          lastAttemptAt: Value(DateTime.now()),
        ));

      final row = await (_db.select(_db.outboxEntries)
        ..where((t) => t.operationId.equals(operationId)))
        .getSingleOrNull();

      if (row == null) {
        return const Failure(NotFoundFailure(message: 'Operation not found'));
      }
      return Success(_mapToSyncOperation(row));
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to update status: $e'));
    }
  }

  @override
  Future<Result<void>> markCompleted(String operationId) async {
    return updateStatus(operationId, SyncOperationStatus.completed)
        .then((r) => r.map((_) {}));
  }

  @override
  Future<Result<SyncOperation>> recordAttempt(
    String operationId, {
    String? error,
  }) async {
    try {
      final row = await (_db.select(_db.outboxEntries)
        ..where((t) => t.operationId.equals(operationId)))
        .getSingleOrNull();

      if (row == null) {
        return const Failure(NotFoundFailure(message: 'Operation not found'));
      }

      final newRetryCount = row.retryCount + 1;
      final newStatus = newRetryCount >= 5 ? 'failed' : 'pending';

      await (_db.update(_db.outboxEntries)
        ..where((t) => t.operationId.equals(operationId)))
        .write(OutboxEntriesCompanion(
          retryCount: Value(newRetryCount),
          status: Value(newStatus),
          lastError: Value(error),
          lastAttemptAt: Value(DateTime.now()),
        ));

      final updated = await (_db.select(_db.outboxEntries)
        ..where((t) => t.operationId.equals(operationId)))
        .getSingle();

      return Success(_mapToSyncOperation(updated));
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to record attempt: $e'));
    }
  }

  @override
  Future<Result<int>> cleanup({Duration olderThan = const Duration(days: 7)}) async {
    try {
      final cutoff = DateTime.now().subtract(olderThan);
      final count = await (_db.delete(_db.outboxEntries)
        ..where((t) => t.status.equals('completed') & t.createdAt.isSmallerThanValue(cutoff)))
        .go();
      return Success(count);
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to cleanup: $e'));
    }
  }

  @override
  Future<Result<int>> getPendingCount() async {
    try {
      final count = await (_db.select(_db.outboxEntries)
        ..where((t) => t.status.equals('pending')))
        .get();
      return Success(count.length);
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to get count: $e'));
    }
  }

  @override
  Future<Result<List<SyncOperation>>> getRetryable() async {
    try {
      final now = DateTime.now();
      final rows = await (_db.select(_db.outboxEntries)
        ..where((t) => t.status.equals('pending')))
        .get();

      final retryable = rows.where((row) {
        if (row.lastAttemptAt == null) return true;
        final backoff = Duration(seconds: 1 << row.retryCount);
        return now.isAfter(row.lastAttemptAt!.add(backoff));
      }).map(_mapToSyncOperation).toList();

      return Success(retryable);
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to get retryable: $e'));
    }
  }

  @override
  Future<Result<void>> cancelForEntity(String entityType, String entityId) async {
    try {
      await (_db.update(_db.outboxEntries)
        ..where((t) =>
            t.entityType.equals(entityType) &
            t.entityId.equals(entityId) &
            t.status.equals('pending')))
        .write(const OutboxEntriesCompanion(status: Value('cancelled')));
      return const Success(null);
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to cancel: $e'));
    }
  }

  SyncOperation _mapToSyncOperation(OutboxEntry row) {
    return SyncOperation(
      id: row.operationId,
      entityType: row.entityType,
      entityId: row.entityId,
      operationType: SyncOperationType.values.firstWhere(
        (e) => e.name == row.operationType,
        orElse: () => SyncOperationType.create,
      ),
      payload: row.payload,
      priority: SyncPriority.values[row.priority.clamp(0, 3)],
      status: SyncOperationStatus.values.firstWhere(
        (e) => e.name == row.status,
        orElse: () => SyncOperationStatus.pending,
      ),
      retryCount: row.retryCount,
      lastError: row.lastError,
      createdAt: row.createdAt,
      lastAttemptAt: row.lastAttemptAt,
    );
  }
}

