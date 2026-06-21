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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'hour': hour,
      'minute': minute,
      'repeat_daily': repeatDaily,
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
      date: json['date'] as String?,
      scheduledAt: DateTime.tryParse(json['scheduled_at'] as String? ?? '') ??
          DateTime.now(),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
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
  });

  final String title;
  final String message;
  final int hour;
  final int minute;
  final bool repeatDaily;
  final String? date;
}

abstract interface class AgentNotificationSchedulingService {
  Future<ScheduledAgentNotification> scheduleNotification(
    ScheduleAgentNotificationRequest request,
  );

  Future<List<ScheduledAgentNotification>> getScheduledNotifications();

  Future<void> cancelNotification(int id);
}

class NotificationPermissionDeniedException implements Exception {
  const NotificationPermissionDeniedException();
}

class LocalAgentNotificationScheduler
    implements AgentNotificationSchedulingService {
  LocalAgentNotificationScheduler({
    FlutterLocalNotificationsPlugin? notificationsPlugin,
    SharedPreferencesAsync? preferences,
  }) : _notificationsPlugin =
           notificationsPlugin ?? FlutterLocalNotificationsPlugin(),
       _preferences = preferences ?? SharedPreferencesAsync();

  static final LocalAgentNotificationScheduler instance =
      LocalAgentNotificationScheduler();

  static const _storageKey = 'agent_scheduled_notifications_v1';
  static const _channelId = 'agent_reminders';
  static const _channelName = 'Agent Reminders';
  static const _channelDescription = 'Reminders scheduled by Airo agent skills';

  final FlutterLocalNotificationsPlugin _notificationsPlugin;
  final SharedPreferencesAsync _preferences;
  bool _initialized = false;
  bool _timeZoneInitialized = false;

  @override
  Future<ScheduledAgentNotification> scheduleNotification(
    ScheduleAgentNotificationRequest request,
  ) async {
    _validate(request);
    await _ensureInitialized();
    final hasPermission = await _requestNotificationPermission();
    if (!hasPermission) {
      throw const NotificationPermissionDeniedException();
    }

    final createdAt = DateTime.now();
    final scheduledDate = _scheduledDateFor(request);
    if (!request.repeatDaily && !scheduledDate.isAfter(tz.TZDateTime.now(tz.local))) {
      throw ArgumentError.value(request.date, 'date', 'Reminder time is in the past.');
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
      matchDateTimeComponents:
          request.repeatDaily ? DateTimeComponents.time : null,
    );

    final notifications = await getScheduledNotifications();
    await _saveScheduledNotifications([
      ...notifications.where((item) => item.id != notification.id),
      notification,
    ]);

    return notification;
  }

  @override
  Future<List<ScheduledAgentNotification>> getScheduledNotifications() async {
    final raw = await _preferences.getString(_storageKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      final notifications = decoded
          .whereType<Map>()
          .map((item) {
            return ScheduledAgentNotification.fromJson(
              item.cast<String, dynamic>(),
            );
          })
          .toList();
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
    if (!request.repeatDaily && date != null && date.isNotEmpty) {
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
    await _preferences.setString(
      _storageKey,
      jsonEncode(notifications.map((item) => item.toJson()).toList()),
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
}
