import 'package:core_domain/core_domain.dart';
import 'offline_repository.dart';

/// Sync engine state.
enum SyncEngineState {
  idle,
  syncing,
  paused,
  error,
}

/// Sync engine configuration.
class SyncConfig {
  /// Interval between automatic syncs.
  final Duration syncInterval;

  /// Maximum retry attempts for failed syncs.
  final int maxRetries;

  /// Delay between retries (exponential backoff base).
  final Duration retryDelay;

  /// Whether to sync automatically when online.
  final bool autoSync;

  /// Whether to sync on app start.
  final bool syncOnStart;

  /// Batch size for sync operations.
  final int batchSize;

  const SyncConfig({
    this.syncInterval = const Duration(minutes: 5),
    this.maxRetries = 3,
    this.retryDelay = const Duration(seconds: 5),
    this.autoSync = true,
    this.syncOnStart = true,
    this.batchSize = 50,
  });
}

/// Sync engine interface for coordinating offline-first sync.
abstract interface class SyncEngine {
  /// Current sync state.
  SyncEngineState get state;

  /// Stream of sync state changes.
  Stream<SyncEngineState> get stateChanges;

  /// Whether currently online.
  bool get isOnline;

  /// Stream of connectivity changes.
  Stream<bool> get connectivityChanges;

  /// Initialize the sync engine.
  Future<Result<void>> initialize(SyncConfig config);

  /// Start automatic sync.
  Future<void> start();

  /// Stop automatic sync.
  Future<void> stop();

  /// Pause sync (e.g., when app goes to background).
  void pause();

  /// Resume sync.
  void resume();

  /// Trigger immediate sync of all pending changes.
  Future<Result<SyncResult>> syncNow();

  /// Register a repository for sync.
  void registerRepository<TId, T>(String name, SyncableRepository<TId, dynamic> repository);

  /// Unregister a repository.
  void unregisterRepository(String name);

  /// Get sync summary for all repositories.
  Future<Map<String, SyncSummary>> getAllSyncSummaries();

  /// Dispose resources.
  Future<void> dispose();
}

/// Conflict resolution strategy.
enum ConflictResolution {
  /// Local changes win.
  localWins,

  /// Remote changes win.
  remoteWins,

  /// Most recent change wins.
  lastWriteWins,

  /// Manual resolution required.
  manual,
}

/// Conflict resolver interface.
abstract interface class ConflictResolver<T> {
  /// Resolve conflict between local and remote versions.
  Future<T> resolve(T local, T remote, ConflictResolution strategy);
}

/// Network connectivity checker interface.
abstract interface class ConnectivityChecker {
  /// Check if currently online.
  Future<bool> isOnline();

  /// Stream of connectivity changes.
  Stream<bool> get connectivityChanges;
}

