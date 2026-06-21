import '../../domain/models/agent_skill.dart';
import '../../domain/services/agent_connector.dart';
import '../services/agent_notification_scheduler.dart';

class ScheduleNotificationConnector implements AgentConnector {
  ScheduleNotificationConnector({AgentNotificationSchedulingService? scheduler})
    : _scheduler = scheduler ?? LocalAgentNotificationScheduler.instance;

  final AgentNotificationSchedulingService _scheduler;

  @override
  String get name => 'schedule_notification';

  @override
  Set<SkillCapability> get requiredCapabilities => {
    SkillCapability.notificationsSchedule,
  };

  @override
  Future<ConnectorResult> execute(Map<String, dynamic> arguments) async {
    final title = (arguments['title'] as String?)?.trim();
    final message = (arguments['message'] as String?)?.trim();
    final hour = _readInt(arguments['hour']);
    final minute = _readInt(arguments['minute']) ?? 0;
    final repeatDaily = arguments['repeat_daily'] as bool? ?? false;
    final date = (arguments['date'] as String?)?.trim();

    if (title == null || title.isEmpty) {
      return const ConnectorResult.error(
        code: 'missing_title',
        message: 'schedule_notification requires a title.',
      );
    }
    if (message == null || message.isEmpty) {
      return const ConnectorResult.error(
        code: 'missing_message',
        message: 'schedule_notification requires a message.',
      );
    }
    if (hour == null || hour < 0 || hour > 23) {
      return const ConnectorResult.error(
        code: 'invalid_hour',
        message: 'schedule_notification requires hour in 0-23 format.',
      );
    }
    if (minute < 0 || minute > 59) {
      return const ConnectorResult.error(
        code: 'invalid_minute',
        message: 'schedule_notification requires minute in 0-59 format.',
      );
    }

    try {
      final notification = await _scheduler.scheduleNotification(
        ScheduleAgentNotificationRequest(
          title: title,
          message: message,
          hour: hour,
          minute: minute,
          repeatDaily: repeatDaily,
          date: date == null || date.isEmpty ? null : date,
        ),
      );

      return ConnectorResult(data: notification.toJson());
    } on NotificationPermissionDeniedException {
      return const ConnectorResult.error(
        code: 'notification_permission_denied',
        message: 'Notification permission was denied.',
      );
    } on FormatException {
      return const ConnectorResult.error(
        code: 'invalid_date',
        message: 'schedule_notification date must be YYYY-MM-DD.',
      );
    } on ArgumentError catch (error) {
      return ConnectorResult.error(
        code: 'invalid_notification',
        message: error.message?.toString() ?? 'Invalid notification request.',
      );
    }
  }
}

class InMemoryNotificationScheduler
    implements AgentNotificationSchedulingService {
  InMemoryNotificationScheduler({DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  final List<ScheduledAgentNotification> scheduled = [];

  @override
  Future<ScheduledAgentNotification> scheduleNotification(
    ScheduleAgentNotificationRequest request,
  ) async {
    final createdAt = _now();
    final scheduledAt = request.date == null
        ? DateTime(
            createdAt.year,
            createdAt.month,
            createdAt.day,
            request.hour,
            request.minute,
          )
        : DateTime.parse(
            request.date!,
          ).copyWith(hour: request.hour, minute: request.minute);
    final notification = ScheduledAgentNotification(
      id: scheduled.length + 1,
      title: request.title,
      message: request.message,
      hour: request.hour,
      minute: request.minute,
      repeatDaily: request.repeatDaily,
      date: request.date,
      scheduledAt: scheduledAt,
      createdAt: createdAt,
    );
    scheduled.add(notification);
    return notification;
  }

  @override
  Future<List<ScheduledAgentNotification>> getScheduledNotifications() async {
    return List.unmodifiable(scheduled);
  }

  @override
  Future<void> cancelNotification(int id) async {
    scheduled.removeWhere((notification) => notification.id == id);
  }
}

int? _readInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}
