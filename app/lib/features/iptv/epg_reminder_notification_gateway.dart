import 'dart:io';

import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

/// App-level local notification gateway for EPG reminders.
class FlutterLocalNotificationsEpgReminderGateway
    implements EpgReminderNotificationGateway {
  FlutterLocalNotificationsEpgReminderGateway({this.onReminderTap});

  static const String _notificationChannelId = 'epg_reminders';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final void Function(String channelId)? onReminderTap;
  bool _initialized = false;

  @override
  bool get isAvailable => !kIsWeb && (Platform.isIOS || Platform.isAndroid);

  Future<void> initialize() async {
    if (_initialized || !isAvailable) return;

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        handleNotificationPayload(response.payload);
      },
    );
    _initialized = true;
  }

  @visibleForTesting
  void handleNotificationPayload(String? payload) {
    if (payload == null || payload.isEmpty) return;
    onReminderTap?.call(payload);
  }

  @override
  Future<bool> requestPermission() async {
    await initialize();

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }

    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      return await ios.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }

    return false;
  }

  @override
  Future<void> schedule({
    required int notificationId,
    required String title,
    required String body,
    required DateTime at,
    required String payloadChannelId,
  }) async {
    await initialize();
    await _plugin.zonedSchedule(
      id: notificationId,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(at, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _notificationChannelId,
          'Program Reminders',
          channelDescription: 'Reminders for upcoming live programs',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payloadChannelId,
    );
  }

  @override
  Future<void> cancel(int notificationId) {
    return _plugin.cancel(id: notificationId);
  }
}
