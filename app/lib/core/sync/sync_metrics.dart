import 'dart:async';

import 'package:core_data/core_data.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Metrics and monitoring for sync operations.
class SyncMetrics {
  SyncMetrics({required OutboxRepository outboxRepository})
    : _outboxRepository = outboxRepository;

  final OutboxRepository _outboxRepository;
  SharedPreferences? _prefs;

  static const _keyPrefix = 'sync_metrics_';
  static const _keyTotalSynced = '${_keyPrefix}total_synced';
  static const _keyTotalFailed = '${_keyPrefix}total_failed';
  static const _keyLastSyncAt = '${_keyPrefix}last_sync_at';
  static const _keyLastSyncDurationMs = '${_keyPrefix}last_sync_duration_ms';
  static const _keyAverageSyncDurationMs = '${_keyPrefix}avg_sync_duration_ms';
  static const _keySyncCount = '${_keyPrefix}sync_count';

  Future<SharedPreferences> get _preferences async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Records the result of a sync operation.
  Future<void> recordSync({
    required int synced,
    required int failed,
    required Duration duration,
  }) async {
    final prefs = await _preferences;

    // Update totals
    final totalSynced = (prefs.getInt(_keyTotalSynced) ?? 0) + synced;
    final totalFailed = (prefs.getInt(_keyTotalFailed) ?? 0) + failed;
    final syncCount = (prefs.getInt(_keySyncCount) ?? 0) + 1;

    // Update averages
    final oldAvg = prefs.getInt(_keyAverageSyncDurationMs) ?? 0;
    final newAvg =
        ((oldAvg * (syncCount - 1)) + duration.inMilliseconds) ~/ syncCount;

    await prefs.setInt(_keyTotalSynced, totalSynced);
    await prefs.setInt(_keyTotalFailed, totalFailed);
    await prefs.setInt(_keySyncCount, syncCount);
    await prefs.setInt(_keyLastSyncDurationMs, duration.inMilliseconds);
    await prefs.setInt(_keyAverageSyncDurationMs, newAvg);
    await prefs.setString(_keyLastSyncAt, DateTime.now().toIso8601String());

    debugPrint(
      'SyncMetrics: Recorded - synced=$synced, failed=$failed, duration=${duration.inMs}ms',
    );
  }

  /// Gets current sync statistics.
  Future<SyncStats> getStats() async {
    final prefs = await _preferences;
    final pendingResult = await _outboxRepository.getPendingCount();

    return SyncStats(
      totalSynced: prefs.getInt(_keyTotalSynced) ?? 0,
      totalFailed: prefs.getInt(_keyTotalFailed) ?? 0,
      pendingCount: pendingResult.valueOrNull ?? 0,
      lastSyncAt: _parseDateTime(prefs.getString(_keyLastSyncAt)),
      lastSyncDuration: Duration(
        milliseconds: prefs.getInt(_keyLastSyncDurationMs) ?? 0,
      ),
      averageSyncDuration: Duration(
        milliseconds: prefs.getInt(_keyAverageSyncDurationMs) ?? 0,
      ),
      syncCount: prefs.getInt(_keySyncCount) ?? 0,
    );
  }

  /// Resets all metrics.
  Future<void> reset() async {
    final prefs = await _preferences;
    await prefs.remove(_keyTotalSynced);
    await prefs.remove(_keyTotalFailed);
    await prefs.remove(_keyLastSyncAt);
    await prefs.remove(_keyLastSyncDurationMs);
    await prefs.remove(_keyAverageSyncDurationMs);
    await prefs.remove(_keySyncCount);
    debugPrint('SyncMetrics: Reset');
  }

  DateTime? _parseDateTime(String? value) {
    if (value == null) return null;
    try {
      return DateTime.parse(value);
    } catch (_) {
      return null;
    }
  }
}

/// Snapshot of sync statistics.
class SyncStats {
  const SyncStats({
    required this.totalSynced,
    required this.totalFailed,
    required this.pendingCount,
    required this.lastSyncAt,
    required this.lastSyncDuration,
    required this.averageSyncDuration,
    required this.syncCount,
  });

  final int totalSynced;
  final int totalFailed;
  final int pendingCount;
  final DateTime? lastSyncAt;
  final Duration lastSyncDuration;
  final Duration averageSyncDuration;
  final int syncCount;

  /// Success rate as a percentage (0-100).
  double get successRate {
    final total = totalSynced + totalFailed;
    if (total == 0) return 100.0;
    return (totalSynced / total) * 100;
  }

  /// Whether there are pending operations.
  bool get hasPending => pendingCount > 0;

  /// Whether sync has ever run.
  bool get hasRun => syncCount > 0;

  /// Time since last sync.
  Duration? get timeSinceLastSync {
    if (lastSyncAt == null) return null;
    return DateTime.now().difference(lastSyncAt!);
  }

  @override
  String toString() {
    return 'SyncStats(synced: $totalSynced, failed: $totalFailed, pending: $pendingCount, '
        'successRate: ${successRate.toStringAsFixed(1)}%, lastSync: $lastSyncAt)';
  }
}

extension on Duration {
  int get inMs => inMilliseconds;
}
