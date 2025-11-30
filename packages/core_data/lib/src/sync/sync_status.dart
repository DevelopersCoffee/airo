import 'package:meta/meta.dart';

/// Represents the current status of the sync service.
@immutable
sealed class SyncStatus {
  const SyncStatus();

  /// Idle - no sync in progress
  const factory SyncStatus.idle() = SyncIdle;

  /// Currently syncing
  const factory SyncStatus.syncing({int? progress, int? total}) = SyncSyncing;

  /// Sync completed
  const factory SyncStatus.completed({
    required int synced,
    required int failed,
  }) = SyncCompleted;

  /// Sync error
  const factory SyncStatus.error(String message) = SyncError;

  /// Whether sync is in progress
  bool get isSyncing => this is SyncSyncing;

  /// Whether sync has errors
  bool get hasError => this is SyncError;
}

/// Idle state - no sync activity
@immutable
class SyncIdle extends SyncStatus {
  const SyncIdle();

  @override
  String toString() => 'SyncStatus.idle';
}

/// Syncing state - sync in progress
@immutable
class SyncSyncing extends SyncStatus {
  const SyncSyncing({this.progress, this.total});

  final int? progress;
  final int? total;

  double? get progressPercent =>
      progress != null && total != null && total! > 0
          ? progress! / total!
          : null;

  @override
  String toString() => 'SyncStatus.syncing($progress/$total)';
}

/// Completed state - sync finished
@immutable
class SyncCompleted extends SyncStatus {
  const SyncCompleted({required this.synced, required this.failed});

  final int synced;
  final int failed;

  bool get hasFailures => failed > 0;

  @override
  String toString() => 'SyncStatus.completed(synced: $synced, failed: $failed)';
}

/// Error state - sync failed
@immutable
class SyncError extends SyncStatus {
  const SyncError(this.message);

  final String message;

  @override
  String toString() => 'SyncStatus.error($message)';
}

/// Conflict resolution strategy
enum ConflictResolution {
  /// Use local version (client wins)
  keepLocal,

  /// Use remote version (server wins)
  keepRemote,

  /// Merge both versions
  merge,

  /// Skip this operation
  skip,

  /// Retry later
  retry,
}

/// Configuration for sync behavior
class SyncConfig {
  const SyncConfig({
    this.syncInterval = const Duration(minutes: 5),
    this.maxRetries = 5,
    this.enableBackgroundSync = true,
    this.syncOnConnectivityChange = true,
    this.batchSize = 10,
    this.defaultConflictResolution = ConflictResolution.keepLocal,
  });

  /// Interval between sync attempts
  final Duration syncInterval;

  /// Maximum retries for failed operations
  final int maxRetries;

  /// Enable background sync (WorkManager/BGTask)
  final bool enableBackgroundSync;

  /// Trigger sync when connectivity changes
  final bool syncOnConnectivityChange;

  /// Number of operations to sync in one batch
  final int batchSize;

  /// Default conflict resolution strategy
  final ConflictResolution defaultConflictResolution;

  /// Default configuration
  static const defaults = SyncConfig();

  /// Configuration for minimal sync (battery saver)
  static const batterySaver = SyncConfig(
    syncInterval: Duration(minutes: 15),
    enableBackgroundSync: false,
    batchSize: 5,
  );
}

