import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../data/repositories/local_transactions_repository.dart';
import '../../domain/models/money_models.dart';

/// Service for syncing local data with remote server
/// Implements offline-outbox pattern with retry logic
class SyncService {
  final LocalTransactionsRepository _transactionsRepo;
  final Connectivity _connectivity;
  
  Timer? _syncTimer;
  bool _isSyncing = false;
  int _retryCount = 0;
  static const int _maxRetries = 3;
  static const Duration _syncInterval = Duration(minutes: 5);
  static const Duration _retryDelay = Duration(seconds: 30);

  // Stream controller for sync status updates
  final _syncStatusController = StreamController<SyncState>.broadcast();
  Stream<SyncState> get syncStatus => _syncStatusController.stream;

  SyncService(this._transactionsRepo, [Connectivity? connectivity])
      : _connectivity = connectivity ?? Connectivity();

  /// Start periodic sync
  void startPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(_syncInterval, (_) => sync());
    
    // Also sync when connectivity changes
    _connectivity.onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none) {
        sync();
      }
    });
  }

  /// Stop periodic sync
  void stopPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  /// Manually trigger sync
  Future<SyncResult> sync() async {
    if (_isSyncing) {
      return SyncResult(
        success: false,
        message: 'Sync already in progress',
        syncedCount: 0,
        failedCount: 0,
      );
    }

    _isSyncing = true;
    _syncStatusController.add(SyncState.syncing);

    try {
      // Check connectivity
      final connectivityResult = await _connectivity.checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        _syncStatusController.add(SyncState.offline);
        return SyncResult(
          success: false,
          message: 'No internet connection',
          syncedCount: 0,
          failedCount: 0,
        );
      }

      // Get pending transactions
      final pendingTransactions = await _transactionsRepo.getPendingSync();
      
      if (pendingTransactions.isEmpty) {
        _syncStatusController.add(SyncState.synced);
        _retryCount = 0;
        return SyncResult(
          success: true,
          message: 'Nothing to sync',
          syncedCount: 0,
          failedCount: 0,
        );
      }

      int syncedCount = 0;
      int failedCount = 0;
      final errors = <String>[];

      for (final transaction in pendingTransactions) {
        try {
          // TODO: Replace with actual API call
          final success = await _syncTransaction(transaction);
          
          if (success) {
            await _transactionsRepo.markSynced(transaction.id);
            syncedCount++;
          } else {
            failedCount++;
            errors.add('Failed to sync: ${transaction.id}');
          }
        } catch (e) {
          failedCount++;
          errors.add('Error syncing ${transaction.id}: $e');
          debugPrint('Sync error for ${transaction.id}: $e');
        }
      }

      if (failedCount > 0 && _retryCount < _maxRetries) {
        _retryCount++;
        _syncStatusController.add(SyncState.retrying);
        Future.delayed(_retryDelay, sync);
      } else {
        _retryCount = 0;
        _syncStatusController.add(
          failedCount == 0 ? SyncState.synced : SyncState.error,
        );
      }

      return SyncResult(
        success: failedCount == 0,
        message: failedCount == 0 
            ? 'Synced $syncedCount transactions'
            : 'Synced $syncedCount, failed $failedCount',
        syncedCount: syncedCount,
        failedCount: failedCount,
        errors: errors,
      );
    } catch (e, s) {
      debugPrint('Sync failed: $e\n$s');
      _syncStatusController.add(SyncState.error);
      return SyncResult(
        success: false,
        message: 'Sync failed: $e',
        syncedCount: 0,
        failedCount: 0,
      );
    } finally {
      _isSyncing = false;
    }
  }

  /// Sync a single transaction to remote server
  Future<bool> _syncTransaction(Transaction transaction) async {
    // TODO: Implement actual API call
    // For now, simulate network delay and success
    await Future.delayed(const Duration(milliseconds: 100));
    return true;
  }

  /// Dispose resources
  void dispose() {
    stopPeriodicSync();
    _syncStatusController.close();
  }
}

/// Sync states
enum SyncState {
  idle,
  syncing,
  synced,
  retrying,
  error,
  offline,
}

/// Result of a sync operation
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

