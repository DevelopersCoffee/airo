import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../models/quest_models.dart';

/// Reminder notification service
abstract interface class ReminderService {
  /// Initialize notification service
  Future<void> initialize();

  /// Schedule a reminder notification
  Future<void> scheduleReminder(QuestReminder reminder);

  /// Cancel a reminder notification
  Future<void> cancelReminder(String reminderId);

  /// Get all scheduled reminders
  Future<List<QuestReminder>> getScheduledReminders();

  /// Update reminder
  Future<void> updateReminder(QuestReminder reminder);
}

/// Fake implementation for development
class FakeReminderService implements ReminderService {
  final Map<String, QuestReminder> _reminders = {};
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  @override
  Future<void> initialize() async {
    // Initialize local notifications
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(initSettings);
  }

  @override
  Future<void> scheduleReminder(QuestReminder reminder) async {
    _reminders[reminder.id] = reminder;

    // Calculate delay
    final now = DateTime.now();
    final delay = reminder.scheduledTime.difference(now);

    if (delay.isNegative) {
      // Reminder time is in the past, show immediately
      await _showNotification(reminder);
    } else {
      // Convert DateTime to TZDateTime
      final tzDateTime = tz.TZDateTime.from(reminder.scheduledTime, tz.local);

      // Schedule for future time
      await _notificationsPlugin.zonedSchedule(
        reminder.id.hashCode,
        reminder.title,
        reminder.description,
        tzDateTime,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'quest_reminders',
            'Quest Reminders',
            channelDescription: 'Notifications for Quest reminders',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    }
  }

  @override
  Future<void> cancelReminder(String reminderId) async {
    _reminders.remove(reminderId);
    await _notificationsPlugin.cancel(reminderId.hashCode);
  }

  @override
  Future<List<QuestReminder>> getScheduledReminders() async {
    return _reminders.values.toList();
  }

  @override
  Future<void> updateReminder(QuestReminder reminder) async {
    // Cancel old reminder
    await cancelReminder(reminder.id);
    // Schedule new reminder
    await scheduleReminder(reminder);
  }

  Future<void> _showNotification(QuestReminder reminder) async {
    await _notificationsPlugin.show(
      reminder.id.hashCode,
      reminder.title,
      reminder.description,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'quest_reminders',
          'Quest Reminders',
          channelDescription: 'Notifications for Quest reminders',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }
}
