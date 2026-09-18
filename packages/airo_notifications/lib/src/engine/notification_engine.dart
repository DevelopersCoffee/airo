import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import '../models/action.dart';
import '../models/alert.dart';
import '../models/group.dart';
import '../models/permission.dart';
import '../storage/alert_store.dart';
import '../storage/in_memory_alert_store.dart';
import '../storage/preferences_alert_store.dart';

abstract interface class AiroNotificationEngine {
  Future<void> initialize({
    void Function(AiroNotificationActionEvent event)? onAction,
    void Function(String payload)? onNotificationPayload,
  });

  Future<void> show(AiroAlert alert, {AiroNotificationGroup? group});

  Future<AiroAlert> schedule(AiroAlert alert, {AiroNotificationGroup? group});

  Future<void> cancel(String alertId);

  Future<void> cancelGroup(String groupId);

  Future<List<AiroAlert>> query({
    AiroAlertType? type,
    AiroAlertStatus? status,
    String? groupId,
    String? taskId,
    String? source,
    bool includeDelivered = false,
  });

  Future<void> reschedule(String alertId, DateTime newScheduledAt);

  Future<void> snooze(String alertId, Duration duration);

  Future<AiroAlert?> markCompleted(String alertId);

  /// Generic upsert used by consumers that own domain-specific bookkeeping
  /// (e.g. streaks/points) on top of an [AiroAlert]. This package never reads
  /// or computes those fields itself -- it only persists whatever the caller
  /// hands it, so gamification/scoring logic stays where it belongs, in the
  /// consuming feature.
  Future<AiroAlert> persist(AiroAlert alert);

  Future<AiroNotificationPermissionStatus> notificationPermissionStatus();

  Future<bool> requestNotificationPermission();

  Future<String?> getLaunchPayload();

  Stream<AiroNotificationActionEvent> get onAction;
}

class LocalAiroNotificationEngine implements AiroNotificationEngine {
  LocalAiroNotificationEngine({
    AlertStore? alertStore,
    FlutterLocalNotificationsPlugin? plugin,
  })  : _store = alertStore ?? (kIsWeb ? InMemoryAlertStore() : PreferencesAlertStore()),
        _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const String _defaultChannelId = 'airo_alerts';
  static const String _defaultChannelName = 'Airo Local Alerts';
  static const String _defaultChannelDescription = 'Alerts and task follow-ups from Airo & Aromind';

  final AlertStore _store;
  final FlutterLocalNotificationsPlugin _plugin;
  final StreamController<AiroNotificationActionEvent> _actionController =
      StreamController<AiroNotificationActionEvent>.broadcast();

  bool _initialized = false;
  bool _timeZoneInitialized = false;
  void Function(String payload)? _onNotificationPayload;

  @override
  Stream<AiroNotificationActionEvent> get onAction => _actionController.stream;

  @override
  Future<void> initialize({
    void Function(AiroNotificationActionEvent event)? onAction,
    void Function(String payload)? onNotificationPayload,
  }) async {
    if (_onNotificationPayload == null && onNotificationPayload != null) {
      _onNotificationPayload = onNotificationPayload;
    }
    if (_initialized) return;
    if (onAction != null) {
      _actionController.stream.listen(onAction);
    }
    _configureTimeZone();

    if (_canDispatchNative) {
      // Must NOT be '@mipmap/ic_launcher' -- adaptive icon (mipmap-anydpi-v26/ic_launcher.xml)
      // shadows that name on API 26+, causing NotificationManager crash due to "no valid small icon".
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_notification');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const settings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
        macOS: iosSettings,
      );

      await _plugin.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: (response) {
          final payload = response.payload;
          if (payload != null && payload.isNotEmpty) {
            _onNotificationPayload?.call(payload);
            _actionController.add(
              AiroNotificationActionEvent(
                alertId: payload,
                action: AiroNotificationActionType.open,
                timestamp: DateTime.now(),
              ),
            );
          }
        },
      );
    }
    _initialized = true;
  }

  @override
  Future<String?> getLaunchPayload() async {
    await initialize();
    if (!_canDispatchNative) return null;
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) {
      return null;
    }
    final payload = details.notificationResponse?.payload;
    if (payload == null || payload.trim().isEmpty) {
      return null;
    }
    return payload;
  }

  @override
  Future<AiroNotificationPermissionStatus> notificationPermissionStatus() async {
    if (kIsWeb) return AiroNotificationPermissionStatus.unavailable;
    try {
      await initialize();
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          final android = _plugin
              .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
          final enabled = await android?.areNotificationsEnabled();
          if (enabled == null) return AiroNotificationPermissionStatus.unavailable;
          return enabled
              ? AiroNotificationPermissionStatus.enabled
              : AiroNotificationPermissionStatus.disabled;
        case TargetPlatform.iOS:
        case TargetPlatform.macOS:
          return AiroNotificationPermissionStatus.enabled;
        case TargetPlatform.fuchsia:
        case TargetPlatform.linux:
        case TargetPlatform.windows:
          return AiroNotificationPermissionStatus.unavailable;
      }
    } catch (_) {
      return AiroNotificationPermissionStatus.unavailable;
    }
  }

  @override
  Future<bool> requestNotificationPermission() async {
    if (kIsWeb) return false;
    try {
      await initialize();
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          final android = _plugin
              .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
          return await android?.requestNotificationsPermission() ?? false;
        case TargetPlatform.iOS:
          final ios = _plugin
              .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
          return await ios?.requestPermissions(
                alert: true,
                badge: true,
                sound: true,
              ) ??
              false;
        case TargetPlatform.macOS:
          final macos = _plugin
              .resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>();
          return await macos?.requestPermissions(
                alert: true,
                badge: true,
                sound: true,
              ) ??
              false;
        case TargetPlatform.fuchsia:
        case TargetPlatform.linux:
        case TargetPlatform.windows:
          return false;
      }
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> show(AiroAlert alert, {AiroNotificationGroup? group}) async {
    _validateAlert(alert);
    await initialize();
    if (_canDispatchNative) {
      final hasPermission = await requestNotificationPermission();
      if (!hasPermission) {
        throw const NotificationPermissionDeniedException();
      }
    }

    final updated = alert.copyWith(
      status: AiroAlertStatus.delivered,
      updatedAt: DateTime.now(),
    );
    await _store.save(updated);

    if (_canDispatchNative) {
      final notificationId = _integerId(alert.id);
      await _plugin.show(
        id: notificationId,
        title: alert.title,
        body: alert.body,
        notificationDetails: _notificationDetailsFor(alert),
        payload: _payloadFor(alert),
      );
    }
  }

  @override
  Future<AiroAlert> schedule(AiroAlert alert, {AiroNotificationGroup? group}) async {
    _validateAlert(alert);
    await initialize();

    final existingAlerts = await _store.query(includeDelivered: true);

    // 1. Idempotency Check by ID (Same request + same ID)
    final existingById = await _store.get(alert.id);
    if (existingById != null) {
      if (_matchesAlert(existingById, alert)) {
        return existingById;
      }
      await cancel(alert.id);
    } else {
      // 2. Semantic Content Deduplication (Same semantic content + different accidental ID)
      for (final existing in existingAlerts) {
        if (_matchesAlert(existing, alert)) {
          return existing;
        }
      }
    }

    if (_canDispatchNative) {
      final hasPermission = await requestNotificationPermission();
      if (!hasPermission) {
        throw const NotificationPermissionDeniedException();
      }
    }

    final scheduledAt = alert.scheduledAt;
    if (scheduledAt != null && !alert.repeatDaily && !scheduledAt.isAfter(DateTime.now())) {
      throw ArgumentError.value(
        scheduledAt,
        'scheduledAt',
        'Reminder time is in the past.',
      );
    }

    final updated = alert.status == AiroAlertStatus.snoozed
        ? alert
        : alert.copyWith(
            status: AiroAlertStatus.pending,
            updatedAt: DateTime.now(),
          );
    await _store.save(updated);

    if (_canDispatchNative && scheduledAt != null) {
      final notificationId = _integerId(alert.id);
      _configureTimeZone();
      final tzScheduledDate = tz.TZDateTime.from(scheduledAt, tz.local);

      await _plugin.zonedSchedule(
        id: notificationId,
        title: alert.title,
        body: alert.body,
        scheduledDate: tzScheduledDate,
        notificationDetails: _notificationDetailsFor(alert),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: alert.repeatDaily ? DateTimeComponents.time : null,
        payload: _payloadFor(updated),
      );
    }

    return updated;
  }

  @override
  Future<void> cancel(String alertId) async {
    await initialize();
    await _store.delete(alertId);
    if (_canDispatchNative) {
      await _plugin.cancel(
        id: _integerId(alertId),
      );
    }
  }

  @override
  Future<void> cancelGroup(String groupId) async {
    await initialize();
    final groupAlerts = await _store.query(groupId: groupId, includeDelivered: true);
    await _store.deleteGroup(groupId);
    if (_canDispatchNative) {
      for (final alert in groupAlerts) {
        await _plugin.cancel(
          id: _integerId(alert.id),
        );
      }
    }
  }

  @override
  Future<List<AiroAlert>> query({
    AiroAlertType? type,
    AiroAlertStatus? status,
    String? groupId,
    String? taskId,
    String? source,
    bool includeDelivered = false,
  }) async {
    await initialize();
    final alerts = await _store.query(
      type: type,
      status: status,
      groupId: groupId,
      taskId: taskId,
      source: source,
      includeDelivered: includeDelivered,
    );
    alerts.sort((a, b) => (a.scheduledAt ?? a.createdAt).compareTo(b.scheduledAt ?? b.createdAt));
    return alerts;
  }

  @override
  Future<void> reschedule(String alertId, DateTime newScheduledAt) async {
    await initialize();
    final existing = await _store.get(alertId);
    if (existing == null) {
      throw StateError('Alert $alertId not found to reschedule.');
    }
    await cancel(alertId);
    final updated = existing.copyWith(
      scheduledAt: newScheduledAt,
      status: AiroAlertStatus.pending,
      updatedAt: DateTime.now(),
    );
    await schedule(updated);
  }

  @override
  Future<void> snooze(String alertId, Duration duration) async {
    await initialize();
    final existing = await _store.get(alertId);
    if (existing == null) {
      throw StateError('Alert $alertId not found to snooze.');
    }

    final newTime = DateTime.now().add(duration);
    await cancel(alertId);
    final snoozedAlert = existing.copyWith(
      scheduledAt: newTime,
      status: AiroAlertStatus.snoozed,
      updatedAt: DateTime.now(),
    );
    await schedule(snoozedAlert);
  }

  @override
  Future<AiroAlert?> markCompleted(String alertId) async {
    await initialize();
    final existing = await _store.get(alertId);
    if (existing == null) return null;

    // Idempotent: a second markCompleted for an already-completed alert must
    // not re-cancel the OS notification or re-emit the action event -- the
    // caller-owned bookkeeping (streaks, points, completion dates) makes its
    // own idempotency decision on top of this by inspecting the alert it
    // gets back from query()/persist() before deciding whether today already
    // counts.
    if (existing.status == AiroAlertStatus.completed) {
      return existing;
    }

    final updated = existing.copyWith(
      status: AiroAlertStatus.completed,
      updatedAt: DateTime.now(),
    );
    await _store.save(updated);

    if (existing.followUpPolicy == 'daily_until_done' && _canDispatchNative) {
      await _plugin.cancel(id: _integerId(alertId));
    }

    _actionController.add(
      AiroNotificationActionEvent(
        alertId: alertId,
        action: AiroNotificationActionType.complete,
        taskId: alertId,
        timestamp: DateTime.now(),
      ),
    );

    return updated;
  }

  @override
  Future<AiroAlert> persist(AiroAlert alert) async {
    await initialize();
    await _store.save(alert);
    return alert;
  }

  bool get _canDispatchNative {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  void _validateAlert(AiroAlert alert) {
    if (alert.title.trim().isEmpty) {
      throw ArgumentError.value(alert.title, 'title', 'Title is required.');
    }
  }

  bool _matchesAlert(AiroAlert a, AiroAlert b) {
    if (a.title == b.title &&
        a.body == b.body &&
        a.repeatDaily == b.repeatDaily &&
        a.groupId == b.groupId) {
      final aSched = a.scheduledAt;
      final bSched = b.scheduledAt;
      if (aSched == null && bSched == null) return true;
      if (aSched != null && bSched != null) {
        if (aSched.hour == bSched.hour && aSched.minute == bSched.minute) {
          return true;
        }
      }
    }
    return false;
  }

  int _integerId(String alertId) {
    return int.tryParse(alertId) ?? (alertId.hashCode & 0x7fffffff);
  }

  NotificationDetails _notificationDetailsFor(AiroAlert alert) {
    final groupId = alert.groupId ?? _defaultChannelId;
    final androidDetails = AndroidNotificationDetails(
      groupId,
      _defaultChannelName,
      channelDescription: _defaultChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
    );
    const darwinDetails = DarwinNotificationDetails();
    return NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );
  }

  String _payloadFor(AiroAlert alert) {
    final deepLink = (alert.metadata['deep_link'] as String?) ??
        '/notifications?alert_id=${Uri.encodeComponent(alert.id)}';
    final intId = int.tryParse(alert.id) ?? (alert.id.hashCode & 0x7fffffff);
    final payload = <String, dynamic>{
      'version': 1,
      'notification_id': intId,
      'id': alert.id,
      'title': alert.title,
      'body': alert.body,
      'category': (alert.metadata['category'] as String?) ?? alert.groupId ?? 'general',
      'schedule_type': (alert.metadata['schedule_type'] as String?) ?? alert.type.stableId,
      'scheduled_at': alert.scheduledAt?.toIso8601String(),
      'repeat_daily': alert.repeatDaily,
      if (alert.groupId != null) 'group_id': alert.groupId,
      'requires_completion': alert.requiresCompletion,
      'follow_up_policy': alert.followUpPolicy,
      'completed_dates': alert.completedDates,
      'streak_count': alert.streakCount,
      'points': alert.points,
      'deep_link': deepLink,
      if (alert.metadata.isNotEmpty) 'metadata': alert.metadata,
    };
    return _canonicalJson(payload);
  }

  void _configureTimeZone() {
    if (_timeZoneInitialized) return;
    tz_data.initializeTimeZones();
    final now = DateTime.now();
    final abbreviation = now.timeZoneName.isEmpty ? 'LOCAL' : now.timeZoneName;
    tz.setLocalLocation(
      tz.Location('local', [tz.minTime], [0], [
        tz.TimeZone(
          now.timeZoneOffset,
          isDst: abbreviation.toUpperCase().contains('DT'),
          abbreviation: abbreviation,
        ),
      ]),
    );
    _timeZoneInitialized = true;
  }
}

String _canonicalJson(Object? value) {
  return jsonEncode(_canonicalizeJson(value));
}

Object? _canonicalizeJson(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((key) => key.toString()).toList()..sort();
    return <String, Object?>{
      for (final key in keys) key: _canonicalizeJson(value[key]),
    };
  }
  if (value is List) {
    return value.map(_canonicalizeJson).toList();
  }
  return value;
}
