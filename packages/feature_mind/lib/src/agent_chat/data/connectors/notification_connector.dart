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
    final category = (arguments['category'] as String?)?.trim() ?? 'general';
    final scheduleType =
        (arguments['schedule_type'] as String?)?.trim() ?? 'daily_time';
    final groupId =
        (arguments['group_id'] as String?)?.trim() ?? _newGroupId(category);
    final metadata =
        (arguments['metadata'] as Map?)?.cast<String, dynamic>() ?? const {};
    final requiresCompletion =
        arguments['requires_completion'] as bool? ??
        metadata['requires_completion'] as bool? ??
        false;
    final followUpPolicy =
        (arguments['follow_up_policy'] as String?)?.trim() ??
        metadata['follow_up_policy'] as String? ??
        'none';
    final times = _readTimes(arguments['times']);

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
    if (hour == null && times.isEmpty) {
      return const ConnectorResult.error(
        code: 'missing_time',
        message: 'schedule_notification requires at least one time.',
      );
    }
    if (hour != null && (hour < 0 || hour > 23)) {
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
      final scheduleTimes = times.isEmpty
          ? [(hour: hour!, minute: minute)]
          : times;
      final notifications = <ScheduledAgentNotification>[];
      for (final time in scheduleTimes) {
        final notification = await _scheduler.scheduleNotification(
          ScheduleAgentNotificationRequest(
            title: title,
            message: message,
            hour: time.hour,
            minute: time.minute,
            repeatDaily: repeatDaily,
            date: date == null || date.isEmpty ? null : date,
            category: category,
            scheduleType: scheduleType,
            groupId: groupId,
            metadata: metadata,
            requiresCompletion: requiresCompletion,
            followUpPolicy: followUpPolicy,
          ),
        );
        notifications.add(notification);
      }

      return ConnectorResult(
        data: {
          ...notifications.first.toJson(),
          'notifications': notifications.map((item) => item.toJson()).toList(),
        },
      );
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
      category: request.category,
      scheduleType: request.scheduleType,
      groupId: request.groupId,
      metadata: request.metadata,
      requiresCompletion: request.requiresCompletion,
      followUpPolicy: request.followUpPolicy,
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

  @override
  Future<ScheduledAgentNotification?> markNotificationComplete(int id) async {
    final index = scheduled.indexWhere((notification) => notification.id == id);
    if (index == -1) return null;
    final notification = scheduled[index];
    final today = _formatDate(_now());
    if (notification.completedDates.contains(today)) return notification;
    final updated = notification.copyWith(
      completedDates: [...notification.completedDates, today],
      streakCount: notification.streakCount + 1,
      points: notification.points + 10,
    );
    scheduled[index] = updated;
    return updated;
  }
}

int? _readInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

List<({int hour, int minute})> _readTimes(Object? value) {
  if (value is! List) return const [];
  final times = <({int hour, int minute})>[];
  for (final item in value) {
    if (item is! Map) continue;
    final hour = _readInt(item['hour']);
    final minute = _readInt(item['minute']) ?? 0;
    if (hour == null || hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      continue;
    }
    times.add((hour: hour, minute: minute));
  }
  return times;
}

String _newGroupId(String category) {
  return '$category-${DateTime.now().microsecondsSinceEpoch}';
}

String _formatDate(DateTime value) {
  return '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
