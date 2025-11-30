import 'dart:async';

import 'package:core_domain/core_domain.dart';

import '../connectivity/connectivity_service.dart';
import 'outbox_repository.dart';
import 'sync_operation.dart';

/// Service for managing offline-first sync operations.
///
/// Handles:
/// - Queue operations for later sync
/// - Process outbox when online
/// - Retry failed operations with exponential backoff
/// - Conflict resolution
class SyncService {
  SyncService({
    required OutboxRepository outboxRepository,
    required ConnectivityService connectivityService,
    this.onSyncOperation,
    this.conflictResolver,
  })  : _outboxRepository = outboxRepository,
        _connectivityService = connectivityService;

  final OutboxRepository _outboxRepository;
  final ConnectivityService _connectivityService;

  /// Callback to perform the actual sync to server.
  /// Returns true if successful, false if failed.
  final Future<bool> Function(SyncOperation operation)? onSyncOperation;

  /// Callback to resolve conflicts between local and remote data.
  final Future<ConflictResolution> Function(SyncOperation operation)?
      conflictResolver;

  Timer? _syncTimer;
  bool _isSyncing = false;
  StreamSubscription<bool>? _connectivitySubscription;

  final _statusController = StreamController<SyncStatus>.broadcast();

  /// Stream of sync status updates
  Stream<SyncStatus> get statusStream => _statusController.stream;

  /// Current sync status
  SyncStatus _status = const SyncStatus.idle();
  SyncStatus get status => _status;

  /// Starts the sync service.
  void start({Duration interval = const Duration(minutes: 5)}) {
    // Listen for connectivity changes
    _connectivitySubscription = _connectivityService.onConnectivityChanged
        .listen((isConnected) {
      if (isConnected) {
        // Trigger sync when coming back online
        processOutbox();
      }
    });

    // Periodic sync
    _syncTimer = Timer.periodic(interval, (_) => processOutbox());
  }

  /// Stops the sync service.
  void stop() {
    _syncTimer?.cancel();
    _syncTimer = null;
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
  }

  /// Queues an operation for sync.
  Future<Result<SyncOperation>> queueOperation({
    required String entityType,
    required String entityId,
    required SyncOperationType operationType,
    required String payload,
    SyncPriority priority = SyncPriority.normal,
  }) async {
    final operation = SyncOperation(
      id: '${entityType}_${entityId}_${DateTime.now().millisecondsSinceEpoch}',
      entityType: entityType,
      entityId: entityId,
      operationType: operationType,
      payload: payload,
      createdAt: DateTime.now(),
      priority: priority,
    );

    final result = await _outboxRepository.add(operation);

    // Try to sync immediately if online and high priority
    if (result.isSuccess &&
        priority.index >= SyncPriority.high.index &&
        await _connectivityService.isConnected) {
      processOutbox();
    }

    return result;
  }

  /// Processes all pending operations in the outbox.
  Future<void> processOutbox() async {
    if (_isSyncing) return;
    if (!await _connectivityService.isConnected) return;

    _isSyncing = true;
    _updateStatus(const SyncStatus.syncing());

    try {
      final pendingResult = await _outboxRepository.getRetryable();
      if (pendingResult.isFailure) {
        _updateStatus(SyncStatus.error(pendingResult.failure.message));
        return;
      }

      final pending = pendingResult.value;
      if (pending.isEmpty) {
        _updateStatus(const SyncStatus.idle());
        return;
      }

      var synced = 0;
      var failed = 0;

      for (final operation in pending) {
        final success = await _syncOperation(operation);
        if (success) {
          synced++;
        } else {
          failed++;
        }
      }

      _updateStatus(SyncStatus.completed(synced: synced, failed: failed));
    } finally {
      _isSyncing = false;
    }
  }

  Future<bool> _syncOperation(SyncOperation operation) async {
    // Mark as in progress
    await _outboxRepository.updateStatus(
      operation.id,
      SyncOperationStatus.inProgress,
    );

    try {
      final success = await onSyncOperation?.call(operation) ?? false;

      if (success) {
        await _outboxRepository.markCompleted(operation.id);
        return true;
      } else {
        await _outboxRepository.recordAttempt(
          operation.id,
          error: 'Sync failed',
        );
        return false;
      }
    } catch (e) {
      await _outboxRepository.recordAttempt(
        operation.id,
        error: e.toString(),
      );
      return false;
    }
  }

  void _updateStatus(SyncStatus newStatus) {
    _status = newStatus;
    _statusController.add(newStatus);
  }

  /// Gets the count of pending operations.
  Future<int> getPendingCount() async {
    final result = await _outboxRepository.getPendingCount();
    return result.valueOrNull ?? 0;
  }

  /// Disposes resources.
  void dispose() {
    stop();
    _statusController.close();
  }
}

