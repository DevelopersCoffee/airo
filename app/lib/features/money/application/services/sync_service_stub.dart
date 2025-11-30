/// Stub for SyncService on web platform
import 'dart:async';

/// Stub service for web - no-op sync
class SyncService {
  SyncService(dynamic transactionsRepo);

  final _syncStatusController = StreamController<SyncState>.broadcast();
  Stream<SyncState> get syncStatus => _syncStatusController.stream;

  void startPeriodicSync() {
    _syncStatusController.add(SyncState.synced);
  }

  void stopPeriodicSync() {}

  Future<SyncResult> sync() async {
    _syncStatusController.add(SyncState.synced);
    return const SyncResult(
      success: true,
      message: 'Web platform - sync not available',
      syncedCount: 0,
      failedCount: 0,
    );
  }

  void dispose() {
    _syncStatusController.close();
  }
}

enum SyncState {
  idle,
  syncing,
  synced,
  retrying,
  error,
  offline,
}

class SyncResult {
  final bool success;
  final String message;
  final int syncedCount;
  final int failedCount;
  final List<String> errors;

  const SyncResult({
    required this.success,
    required this.message,
    required this.syncedCount,
    required this.failedCount,
    this.errors = const [],
  });

  @override
  String toString() => 'SyncResult(success: $success, synced: $syncedCount, failed: $failedCount)';
}

