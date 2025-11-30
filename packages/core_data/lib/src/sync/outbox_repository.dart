import 'package:core_domain/core_domain.dart';

import 'sync_operation.dart';

/// Repository interface for managing the sync outbox.
///
/// The outbox stores pending operations that need to be synced to the server.
abstract class OutboxRepository {
  /// Adds an operation to the outbox.
  Future<Result<SyncOperation>> add(SyncOperation operation);

  /// Gets all pending operations, ordered by priority and creation time.
  Future<Result<List<SyncOperation>>> getPending();

  /// Gets operations for a specific entity.
  Future<Result<List<SyncOperation>>> getForEntity(
    String entityType,
    String entityId,
  );

  /// Updates an operation's status after sync attempt.
  Future<Result<SyncOperation>> updateStatus(
    String operationId,
    SyncOperationStatus status, {
    String? error,
  });

  /// Marks an operation as completed (synced successfully).
  Future<Result<void>> markCompleted(String operationId);

  /// Increments retry count and updates last attempt time.
  Future<Result<SyncOperation>> recordAttempt(
    String operationId, {
    String? error,
  });

  /// Removes completed operations older than the given duration.
  Future<Result<int>> cleanup({Duration olderThan = const Duration(days: 7)});

  /// Gets the count of pending operations.
  Future<Result<int>> getPendingCount();

  /// Gets operations that are ready for retry (past their backoff period).
  Future<Result<List<SyncOperation>>> getRetryable();

  /// Cancels all pending operations for an entity (e.g., on delete).
  Future<Result<void>> cancelForEntity(String entityType, String entityId);
}

/// In-memory implementation for testing.
class InMemoryOutboxRepository implements OutboxRepository {
  final Map<String, SyncOperation> _operations = {};

  @override
  Future<Result<SyncOperation>> add(SyncOperation operation) async {
    _operations[operation.id] = operation;
    return Success(operation);
  }

  @override
  Future<Result<List<SyncOperation>>> getPending() async {
    final pending = _operations.values
        .where((op) => op.status == SyncOperationStatus.pending)
        .toList()
      ..sort((a, b) {
        // Sort by priority (higher first), then by creation time
        final priorityCompare = b.priority.index.compareTo(a.priority.index);
        if (priorityCompare != 0) return priorityCompare;
        return a.createdAt.compareTo(b.createdAt);
      });
    return Success(pending);
  }

  @override
  Future<Result<List<SyncOperation>>> getForEntity(
    String entityType,
    String entityId,
  ) async {
    final ops = _operations.values
        .where((op) => op.entityType == entityType && op.entityId == entityId)
        .toList();
    return Success(ops);
  }

  @override
  Future<Result<SyncOperation>> updateStatus(
    String operationId,
    SyncOperationStatus status, {
    String? error,
  }) async {
    final op = _operations[operationId];
    if (op == null) {
      return const Failure(NotFoundFailure(message: 'Operation not found'));
    }
    final updated = op.copyWith(status: status, lastError: error);
    _operations[operationId] = updated;
    return Success(updated);
  }

  @override
  Future<Result<void>> markCompleted(String operationId) async {
    final result = await updateStatus(
      operationId,
      SyncOperationStatus.completed,
    );
    return result.map((_) {});
  }

  @override
  Future<Result<SyncOperation>> recordAttempt(
    String operationId, {
    String? error,
  }) async {
    final op = _operations[operationId];
    if (op == null) {
      return const Failure(NotFoundFailure(message: 'Operation not found'));
    }
    final updated = op.copyWith(
      retryCount: op.retryCount + 1,
      lastAttemptAt: DateTime.now(),
      lastError: error,
      status: op.canRetry
          ? SyncOperationStatus.pending
          : SyncOperationStatus.failed,
    );
    _operations[operationId] = updated;
    return Success(updated);
  }

  @override
  Future<Result<int>> cleanup({Duration olderThan = const Duration(days: 7)}) async {
    final cutoff = DateTime.now().subtract(olderThan);
    final toRemove = _operations.entries
        .where((e) =>
            e.value.status == SyncOperationStatus.completed &&
            e.value.createdAt.isBefore(cutoff))
        .map((e) => e.key)
        .toList();
    for (final id in toRemove) {
      _operations.remove(id);
    }
    return Success(toRemove.length);
  }

  @override
  Future<Result<int>> getPendingCount() async {
    final count = _operations.values
        .where((op) => op.status == SyncOperationStatus.pending)
        .length;
    return Success(count);
  }

  @override
  Future<Result<List<SyncOperation>>> getRetryable() async {
    final now = DateTime.now();
    final retryable = _operations.values.where((op) {
      if (op.status != SyncOperationStatus.pending) return false;
      if (op.lastAttemptAt == null) return true;
      return now.isAfter(op.lastAttemptAt!.add(op.retryDelay));
    }).toList();
    return Success(retryable);
  }

  @override
  Future<Result<void>> cancelForEntity(
    String entityType,
    String entityId,
  ) async {
    final toCancel = _operations.entries
        .where((e) =>
            e.value.entityType == entityType &&
            e.value.entityId == entityId &&
            e.value.status == SyncOperationStatus.pending)
        .map((e) => e.key)
        .toList();
    for (final id in toCancel) {
      _operations[id] = _operations[id]!.copyWith(
        status: SyncOperationStatus.cancelled,
      );
    }
    return const Success(null);
  }
}

