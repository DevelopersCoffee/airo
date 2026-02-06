import 'dart:async';
import 'dart:io';

import 'package:core_data/core_data.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Background sync service that uses platform-specific APIs.
///
/// - Android: WorkManager
/// - iOS: BGTaskScheduler
/// - Web: Service Worker (if available)
class BackgroundSyncService {
  BackgroundSyncService({required SyncService syncService})
    : _syncService = syncService;

  final SyncService _syncService;

  static const _channel = MethodChannel('com.airo.superapp/background_sync');
  static const _minSyncIntervalMinutes = 15; // Minimum for battery efficiency

  bool _isRegistered = false;

  /// Registers background sync tasks with the platform.
  Future<bool> register({
    Duration interval = const Duration(minutes: 15),
    bool requiresNetwork = true,
    bool requiresCharging = false,
  }) async {
    if (_isRegistered) return true;

    try {
      if (kIsWeb) {
        // Web: Service Workers handled differently
        debugPrint('BackgroundSync: Web platform - using foreground sync only');
        return false;
      }

      final result = await _channel.invokeMethod<bool>('register', {
        'intervalMinutes': interval.inMinutes.clamp(
          _minSyncIntervalMinutes,
          1440,
        ),
        'requiresNetwork': requiresNetwork,
        'requiresCharging': requiresCharging,
        'taskName': 'airo_sync',
      });

      _isRegistered = result ?? false;
      debugPrint('BackgroundSync: Registered = $_isRegistered');
      return _isRegistered;
    } on PlatformException catch (e) {
      debugPrint('BackgroundSync: Registration failed - ${e.message}');
      return false;
    } on MissingPluginException {
      debugPrint('BackgroundSync: Platform not supported');
      return false;
    }
  }

  /// Cancels background sync registration.
  Future<void> cancel() async {
    if (!_isRegistered) return;

    try {
      await _channel.invokeMethod('cancel', {'taskName': 'airo_sync'});
      _isRegistered = false;
      debugPrint('BackgroundSync: Cancelled');
    } catch (e) {
      debugPrint('BackgroundSync: Cancel failed - $e');
    }
  }

  /// Triggers an immediate sync (foreground).
  Future<void> syncNow() async {
    debugPrint('BackgroundSync: Manual sync triggered');
    await _syncService.processOutbox();
  }

  /// Called by native code when background sync is triggered.
  static Future<bool> onBackgroundSync() async {
    debugPrint('BackgroundSync: Background task started');
    // This is called from native code
    // The actual sync service should be retrieved from a static reference
    // or dependency injection container
    return true;
  }

  /// Gets the current sync status.
  SyncStatus get status => _syncService.status;

  /// Stream of sync status updates.
  Stream<SyncStatus> get statusStream => _syncService.statusStream;

  /// Gets count of pending operations.
  Future<int> getPendingCount() => _syncService.getPendingCount();
}

/// Configuration for background sync behavior.
class BackgroundSyncConfig {
  const BackgroundSyncConfig({
    this.enabled = true,
    this.intervalMinutes = 15,
    this.requiresNetwork = true,
    this.requiresCharging = false,
    this.syncOnAppResume = true,
    this.syncOnConnectivityChange = true,
  });

  /// Whether background sync is enabled.
  final bool enabled;

  /// Minimum interval between syncs in minutes.
  final int intervalMinutes;

  /// Whether sync requires network connectivity.
  final bool requiresNetwork;

  /// Whether sync requires device to be charging.
  final bool requiresCharging;

  /// Whether to sync when app resumes from background.
  final bool syncOnAppResume;

  /// Whether to sync when connectivity changes (online).
  final bool syncOnConnectivityChange;

  /// Default configuration.
  static const defaults = BackgroundSyncConfig();

  /// Battery-saver configuration.
  static const batterySaver = BackgroundSyncConfig(
    intervalMinutes: 60,
    requiresCharging: true,
  );

  /// Copy with modifications.
  BackgroundSyncConfig copyWith({
    bool? enabled,
    int? intervalMinutes,
    bool? requiresNetwork,
    bool? requiresCharging,
    bool? syncOnAppResume,
    bool? syncOnConnectivityChange,
  }) {
    return BackgroundSyncConfig(
      enabled: enabled ?? this.enabled,
      intervalMinutes: intervalMinutes ?? this.intervalMinutes,
      requiresNetwork: requiresNetwork ?? this.requiresNetwork,
      requiresCharging: requiresCharging ?? this.requiresCharging,
      syncOnAppResume: syncOnAppResume ?? this.syncOnAppResume,
      syncOnConnectivityChange:
          syncOnConnectivityChange ?? this.syncOnConnectivityChange,
    );
  }
}
