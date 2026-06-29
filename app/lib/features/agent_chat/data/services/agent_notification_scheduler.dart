import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class ScheduledAgentNotification {
  const ScheduledAgentNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.hour,
    required this.minute,
    required this.repeatDaily,
    required this.scheduledAt,
    required this.createdAt,
    this.category = 'general',
    this.scheduleType = 'daily_time',
    this.groupId,
    this.metadata = const {},
    this.requiresCompletion = false,
    this.followUpPolicy = 'none',
    this.completedDates = const [],
    this.streakCount = 0,
    this.points = 0,
    this.date,
  });

  final int id;
  final String title;
  final String message;
  final int hour;
  final int minute;
  final bool repeatDaily;
  final String? date;
  final DateTime scheduledAt;
  final DateTime createdAt;
  final String category;
  final String scheduleType;
  final String? groupId;
  final Map<String, dynamic> metadata;
  final bool requiresCompletion;
  final String followUpPolicy;
  final List<String> completedDates;
  final int streakCount;
  final int points;

  ScheduledAgentNotification copyWith({
    List<String>? completedDates,
    int? streakCount,
    int? points,
  }) {
    return ScheduledAgentNotification(
      id: id,
      title: title,
      message: message,
      hour: hour,
      minute: minute,
      repeatDaily: repeatDaily,
      scheduledAt: scheduledAt,
      createdAt: createdAt,
      category: category,
      scheduleType: scheduleType,
      groupId: groupId,
      metadata: metadata,
      requiresCompletion: requiresCompletion,
      followUpPolicy: followUpPolicy,
      completedDates: completedDates ?? this.completedDates,
      streakCount: streakCount ?? this.streakCount,
      points: points ?? this.points,
      date: date,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'hour': hour,
      'minute': minute,
      'repeat_daily': repeatDaily,
      'category': category,
      'schedule_type': scheduleType,
      if (groupId != null) 'group_id': groupId,
      if (metadata.isNotEmpty) 'metadata': metadata,
      'requires_completion': requiresCompletion,
      'follow_up_policy': followUpPolicy,
      'completed_dates': completedDates,
      'streak_count': streakCount,
      'points': points,
      if (date != null) 'date': date,
      'scheduled_at': scheduledAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory ScheduledAgentNotification.fromJson(Map<String, dynamic> json) {
    return ScheduledAgentNotification(
      id: json['id'] as int,
      title: json['title'] as String? ?? 'Reminder',
      message: json['message'] as String? ?? '',
      hour: json['hour'] as int? ?? 9,
      minute: json['minute'] as int? ?? 0,
      repeatDaily: json['repeat_daily'] as bool? ?? false,
      category: json['category'] as String? ?? 'general',
      scheduleType: json['schedule_type'] as String? ?? 'daily_time',
      groupId: json['group_id'] as String?,
      metadata: (json['metadata'] as Map?)?.cast<String, dynamic>() ?? const {},
      requiresCompletion: json['requires_completion'] as bool? ?? false,
      followUpPolicy: json['follow_up_policy'] as String? ?? 'none',
      completedDates:
          (json['completed_dates'] as List?)?.whereType<String>().toList() ??
          const [],
      streakCount: json['streak_count'] as int? ?? 0,
      points: json['points'] as int? ?? 0,
      date: json['date'] as String?,
      scheduledAt:
          DateTime.tryParse(json['scheduled_at'] as String? ?? '') ??
          DateTime.now(),
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class ScheduleAgentNotificationRequest {
  const ScheduleAgentNotificationRequest({
    required this.title,
    required this.message,
    required this.hour,
    required this.minute,
    this.repeatDaily = false,
    this.date,
    this.category = 'general',
    this.scheduleType = 'daily_time',
    this.groupId,
    this.metadata = const {},
    this.requiresCompletion = false,
    this.followUpPolicy = 'none',
  });

  final String title;
  final String message;
  final int hour;
  final int minute;
  final bool repeatDaily;
  final String? date;
  final String category;
  final String scheduleType;
  final String? groupId;
  final Map<String, dynamic> metadata;
  final bool requiresCompletion;
  final String followUpPolicy;
}

abstract interface class AgentNotificationSchedulingService {
  Future<ScheduledAgentNotification> scheduleNotification(
    ScheduleAgentNotificationRequest request,
  );

  Future<List<ScheduledAgentNotification>> getScheduledNotifications();

  Future<void> cancelNotification(int id);

  Future<ScheduledAgentNotification?> markNotificationComplete(int id);
}

class NotificationPermissionDeniedException implements Exception {
  const NotificationPermissionDeniedException();
}

class LocalAgentNotificationScheduler
    implements AgentNotificationSchedulingService {
  LocalAgentNotificationScheduler({
    FlutterLocalNotificationsPlugin? notificationsPlugin,
    SharedPreferencesAsync? preferences,
  }) : this._internal(notificationsPlugin, preferences);

  LocalAgentNotificationScheduler._internal(
    FlutterLocalNotificationsPlugin? notificationsPlugin,
    this._preferences,
  ) : _notificationsPlugin =
          notificationsPlugin ?? FlutterLocalNotificationsPlugin();

  static final LocalAgentNotificationScheduler instance =
      LocalAgentNotificationScheduler();

  static const _storageKey = 'agent_scheduled_notifications_v1';
  static const _channelId = 'agent_reminders';
  static const _channelName = 'Agent Reminders';
  static const _channelDescription = 'Reminders scheduled by Airo agent skills';

  final FlutterLocalNotificationsPlugin _notificationsPlugin;
  SharedPreferencesAsync? _preferences;
  bool _initialized = false;
  bool _timeZoneInitialized = false;

  SharedPreferencesAsync get _asyncPreferences {
    return _preferences ??= SharedPreferencesAsync();
  }

  @override
  Future<ScheduledAgentNotification> scheduleNotification(
    ScheduleAgentNotificationRequest request,
  ) async {
    _validate(request);
    final existingNotifications = await getScheduledNotifications();
    ScheduledAgentNotification? duplicate;
    for (final notification in existingNotifications) {
      if (_matchesRequest(notification, request)) {
        duplicate = notification;
        break;
      }
    }
    if (duplicate != null) {
      return duplicate;
    }

    await _ensureInitialized();
    final hasPermission = await _requestNotificationPermission();
    if (!hasPermission) {
      throw const NotificationPermissionDeniedException();
    }

    final createdAt = DateTime.now();
    final scheduledDate = _scheduledDateFor(request);
    if (!request.repeatDaily &&
        !scheduledDate.isAfter(tz.TZDateTime.now(tz.local))) {
      throw ArgumentError.value(
        request.date,
        'date',
        'Reminder time is in the past.',
      );
    }

    final notification = ScheduledAgentNotification(
      id: _notificationId(createdAt),
      title: request.title,
      message: request.message,
      hour: request.hour,
      minute: request.minute,
      repeatDaily: request.repeatDaily,
      date: request.date,
      scheduledAt: scheduledDate.toLocal(),
      createdAt: createdAt,
      category: request.category,
      scheduleType: request.scheduleType,
      groupId: request.groupId,
      metadata: request.metadata,
      requiresCompletion: request.requiresCompletion,
      followUpPolicy: request.followUpPolicy,
    );

    await _notificationsPlugin.zonedSchedule(
      id: notification.id,
      title: notification.title,
      body: notification.message,
      scheduledDate: scheduledDate,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: request.repeatDaily
          ? DateTimeComponents.time
          : null,
      payload: _payloadFor(notification),
    );

    await _saveScheduledNotifications([
      ...existingNotifications.where((item) => item.id != notification.id),
      notification,
    ]);

    return notification;
  }

  @override
  Future<List<ScheduledAgentNotification>> getScheduledNotifications() async {
    final raw = await _asyncPreferences.getString(_storageKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      final notifications = decoded.whereType<Map>().map((item) {
        return ScheduledAgentNotification.fromJson(
          item.cast<String, dynamic>(),
        );
      }).toList();
      notifications.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
      return notifications;
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> cancelNotification(int id) async {
    await _ensureInitialized();
    await _notificationsPlugin.cancel(id: id);
    final notifications = await getScheduledNotifications();
    await _saveScheduledNotifications(
      notifications.where((item) => item.id != id).toList(),
    );
  }

  @override
  Future<ScheduledAgentNotification?> markNotificationComplete(int id) async {
    final notifications = await getScheduledNotifications();
    final index = notifications.indexWhere((item) => item.id == id);
    if (index == -1) return null;

    final today = _formatDate(DateTime.now());
    final notification = notifications[index];
    if (notification.completedDates.contains(today)) {
      return notification;
    }

    final lastCompletedDate = notification.completedDates.isEmpty
        ? null
        : DateTime.tryParse(notification.completedDates.last);
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final continuesStreak =
        lastCompletedDate != null &&
        _formatDate(lastCompletedDate) == _formatDate(yesterday);

    final updated = notification.copyWith(
      completedDates: [...notification.completedDates, today],
      streakCount: continuesStreak ? notification.streakCount + 1 : 1,
      points: notification.points + 10,
    );
    notifications[index] = updated;
    if (updated.requiresCompletion &&
        updated.followUpPolicy == 'daily_until_done') {
      await _ensureInitialized();
      await _notificationsPlugin.cancel(id: id);
    }
    await _saveScheduledNotifications(notifications);
    return updated;
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    _configureLocalTimeZone();
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _notificationsPlugin.initialize(settings: settings);
    _initialized = true;
  }

  Future<bool> _requestNotificationPermission() async {
    if (kIsWeb) return false;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        final android = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        return await android?.requestNotificationsPermission() ?? true;
      case TargetPlatform.iOS:
        final ios = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
        return await ios?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      case TargetPlatform.macOS:
        final macos = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin
            >();
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
  }

  void _configureLocalTimeZone() {
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

  tz.TZDateTime _scheduledDateFor(ScheduleAgentNotificationRequest request) {
    final date = request.date;
    if (date != null && date.isNotEmpty) {
      final parsed = DateTime.parse(date);
      return tz.TZDateTime(
        tz.local,
        parsed.year,
        parsed.month,
        parsed.day,
        request.hour,
        request.minute,
      );
    }

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      request.hour,
      request.minute,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  Future<void> _saveScheduledNotifications(
    List<ScheduledAgentNotification> notifications,
  ) async {
    final sorted = [...notifications]
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    await _asyncPreferences.setString(
      _storageKey,
      jsonEncode(sorted.map((item) => item.toJson()).toList()),
    );
  }

  int _notificationId(DateTime createdAt) {
    return createdAt.microsecondsSinceEpoch & 0x7fffffff;
  }

  void _validate(ScheduleAgentNotificationRequest request) {
    if (request.title.trim().isEmpty) {
      throw ArgumentError.value(request.title, 'title', 'Title is required.');
    }
    if (request.message.trim().isEmpty) {
      throw ArgumentError.value(
        request.message,
        'message',
        'Message is required.',
      );
    }
    if (request.hour < 0 || request.hour > 23) {
      throw ArgumentError.value(request.hour, 'hour', 'Hour must be 0-23.');
    }
    if (request.minute < 0 || request.minute > 59) {
      throw ArgumentError.value(
        request.minute,
        'minute',
        'Minute must be 0-59.',
      );
    }
  }

  bool _matchesRequest(
    ScheduledAgentNotification notification,
    ScheduleAgentNotificationRequest request,
  ) {
    return notification.title == request.title &&
        notification.message == request.message &&
        notification.hour == request.hour &&
        notification.minute == request.minute &&
        notification.repeatDaily == request.repeatDaily &&
        notification.date == request.date &&
        notification.category == request.category &&
        notification.scheduleType == request.scheduleType &&
        notification.requiresCompletion == request.requiresCompletion &&
        notification.followUpPolicy == request.followUpPolicy &&
        _canonicalJson(notification.metadata) ==
            _canonicalJson(request.metadata);
  }

  String _payloadFor(ScheduledAgentNotification notification) {
    final payload = <String, Object?>{
      'version': 1,
      'notification_id': notification.id,
      'category': notification.category,
      'schedule_type': notification.scheduleType,
      'requires_completion': notification.requiresCompletion,
      if (notification.groupId != null) 'group_id': notification.groupId,
      if (notification.date != null) 'date': notification.date,
      if (notification.metadata case {
        'deep_link': final String deepLink,
      } when deepLink.trim().isNotEmpty)
        'deep_link': deepLink,
      if (notification.metadata.isNotEmpty) 'metadata': notification.metadata,
    };
    return _canonicalJson(payload);
  }
}

String _formatDate(DateTime value) {
  return '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
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
