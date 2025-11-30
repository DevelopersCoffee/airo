import 'sync_status.dart';

/// Base class for entities that can be synced offline.
abstract class SyncableEntity<TId> {
  /// Local ID.
  TId get id;

  /// Sync metadata.
  SyncMetadata get syncMetadata;

  /// Create a copy with updated sync metadata.
  SyncableEntity<TId> withSyncMetadata(SyncMetadata metadata);

  /// Check if entity needs sync.
  bool get needsSync => syncMetadata.needsSync;

  /// Check if entity is synced.
  bool get isSynced => syncMetadata.status == SyncStatus.synced;

  /// Check if entity has sync error.
  bool get hasSyncError => syncMetadata.hasError;
}

/// Mixin for syncable entity implementation.
mixin SyncableEntityMixin<TId> implements SyncableEntity<TId> {
  @override
  bool get needsSync => syncMetadata.needsSync;

  @override
  bool get isSynced => syncMetadata.status == SyncStatus.synced;

  @override
  bool get hasSyncError => syncMetadata.hasError;
}

