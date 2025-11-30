import 'package:core_domain/core_domain.dart';
import 'sync_status.dart';
import 'syncable_entity.dart';

/// Repository interface for offline-first data access.
///
/// Provides local-first operations with optional sync to remote.
abstract interface class OfflineRepository<TId, T extends SyncableEntity<TId>> {
  /// Get entity by ID from local storage.
  Future<Result<T?>> getById(TId id);

  /// Get all entities from local storage.
  Future<Result<List<T>>> getAll();

  /// Get entities that need sync.
  Future<Result<List<T>>> getPendingSync();

  /// Save entity to local storage (marks as pending sync).
  Future<Result<T>> save(T entity);

  /// Save multiple entities to local storage.
  Future<Result<List<T>>> saveAll(List<T> entities);

  /// Delete entity from local storage.
  Future<Result<void>> delete(TId id);

  /// Delete all entities from local storage.
  Future<Result<void>> deleteAll();

  /// Update sync status for an entity.
  Future<Result<T>> updateSyncStatus(TId id, SyncMetadata metadata);

  /// Watch entity changes.
  Stream<T?> watchById(TId id);

  /// Watch all entities.
  Stream<List<T>> watchAll();
}

/// Repository interface for remote data access.
abstract interface class RemoteRepository<TId, T> {
  /// Fetch entity from remote.
  Future<Result<T?>> fetchById(TId id);

  /// Fetch all entities from remote.
  Future<Result<List<T>>> fetchAll();

  /// Push entity to remote.
  Future<Result<T>> push(T entity);

  /// Push multiple entities to remote.
  Future<Result<List<T>>> pushAll(List<T> entities);

  /// Delete entity from remote.
  Future<Result<void>> deleteRemote(TId id);
}

/// Combined offline-first repository with sync capabilities.
abstract interface class SyncableRepository<TId, T extends SyncableEntity<TId>>
    implements OfflineRepository<TId, T> {
  /// Sync a single entity with remote.
  Future<Result<T>> sync(TId id);

  /// Sync all pending entities with remote.
  Future<Result<SyncResult>> syncAll();

  /// Pull latest data from remote.
  Future<Result<List<T>>> pull();

  /// Check if there are pending changes.
  Future<bool> hasPendingChanges();

  /// Get sync status summary.
  Future<SyncSummary> getSyncSummary();
}

/// Result of a sync operation.
class SyncResult {
  final int synced;
  final int failed;
  final int conflicts;
  final List<SyncError> errors;

  const SyncResult({
    this.synced = 0,
    this.failed = 0,
    this.conflicts = 0,
    this.errors = const [],
  });

  bool get hasErrors => failed > 0 || conflicts > 0;
  bool get isSuccess => failed == 0 && conflicts == 0;
}

/// Error during sync.
class SyncError {
  final String entityId;
  final String message;
  final Object? originalError;

  const SyncError({
    required this.entityId,
    required this.message,
    this.originalError,
  });
}

/// Summary of sync status.
class SyncSummary {
  final int total;
  final int synced;
  final int pending;
  final int failed;
  final int conflicts;
  final DateTime? lastSyncAt;

  const SyncSummary({
    this.total = 0,
    this.synced = 0,
    this.pending = 0,
    this.failed = 0,
    this.conflicts = 0,
    this.lastSyncAt,
  });

  double get syncProgress => total > 0 ? synced / total : 1.0;
  bool get isFullySynced => pending == 0 && failed == 0 && conflicts == 0;
}

