import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:platform_notifications/platform_notifications.dart';

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

  factory ScheduledAgentNotification.fromAiroAlert(AiroAlert alert) {
    final sched = alert.scheduledAt ?? alert.createdAt;
    final intId = int.tryParse(alert.id) ?? (alert.id.hashCode & 0x7fffffff);
    return ScheduledAgentNotification(
      id: intId,
      title: alert.title,
      message: alert.body ?? '',
      hour: sched.hour,
      minute: sched.minute,
      repeatDaily: alert.repeatDaily,
      scheduledAt: alert.scheduledAt ?? alert.createdAt,
      createdAt: alert.createdAt,
      category: (alert.metadata['category'] as String?) ?? alert.groupId ?? 'general',
      scheduleType: (alert.metadata['schedule_type'] as String?) ?? alert.type.stableId,
      groupId: alert.groupId,
      metadata: alert.metadata,
      requiresCompletion: alert.requiresCompletion,
      followUpPolicy: alert.followUpPolicy,
      completedDates: alert.completedDates,
      streakCount: alert.streakCount,
      points: alert.points,
      date: alert.metadata['date'] as String?,
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

abstract interface class AgentNotificationRuntimeService {
  Future<void> initialize({
    void Function(String payload)? onNotificationPayload,
  });

  Future<String?> getLaunchPayload();
}

enum AgentNotificationPermissionStatus { enabled, disabled, unavailable }

abstract interface class AgentNotificationPermissionService {
  Future<AgentNotificationPermissionStatus> notificationPermissionStatus();

  Future<bool> requestNotificationPermission();
}

class LocalAgentNotificationScheduler
    implements
        AgentNotificationSchedulingService,
        AgentNotificationRuntimeService,
        AgentNotificationPermissionService {
  LocalAgentNotificationScheduler({
    AiroNotificationEngine? engine,
    FlutterLocalNotificationsPlugin? notificationsPlugin,
    dynamic preferences,
  }) : _engine = engine ??
            LocalAiroNotificationEngine(
              plugin: notificationsPlugin,
            );

  static final LocalAgentNotificationScheduler instance =
      LocalAgentNotificationScheduler();

  final AiroNotificationEngine _engine;

  @override
  Future<void> initialize({
    void Function(String payload)? onNotificationPayload,
  }) async {
    await _engine.initialize(onNotificationPayload: onNotificationPayload);
  }

  @override
  Future<String?> getLaunchPayload() async {
    return _engine.getLaunchPayload();
  }

  @override
  Future<ScheduledAgentNotification> scheduleNotification(
    ScheduleAgentNotificationRequest request,
  ) async {
    _validate(request);
    final scheduledDate = _scheduledDateFor(request);

    final alertId = '${request.category}-${request.title.hashCode}-${request.hour}-${request.minute}';
    final alert = AiroAlert(
      id: alertId,
      title: request.title,
      body: request.message,
      scheduledAt: scheduledDate,
      repeatDaily: request.repeatDaily,
      groupId: request.groupId ?? request.category,
      requiresCompletion: request.requiresCompletion,
      followUpPolicy: request.followUpPolicy,
      metadata: {
        'category': request.category,
        'schedule_type': request.scheduleType,
        if (request.date != null) 'date': request.date,
        ...request.metadata,
      },
    );

    try {
      final scheduledAlert = await _engine.schedule(alert);
      return ScheduledAgentNotification.fromAiroAlert(scheduledAlert);
    } catch (e) {
      if (e is NotificationPermissionDeniedException ||
          e.toString().contains('NotificationPermissionDeniedException')) {
        throw const NotificationPermissionDeniedException();
      }
      rethrow;
    }
  }

  @override
  Future<List<ScheduledAgentNotification>> getScheduledNotifications() async {
    final alerts = await _engine.query(includeDelivered: true);
    final notifications = alerts.map((a) => ScheduledAgentNotification.fromAiroAlert(a)).toList();
    notifications.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return notifications;
  }

  @override
  Future<void> cancelNotification(int id) async {
    final alerts = await _engine.query(includeDelivered: true);
    for (final alert in alerts) {
      final alertIntId = int.tryParse(alert.id) ?? (alert.id.hashCode & 0x7fffffff);
      if (alertIntId == id || alert.id == id.toString()) {
        await _engine.cancel(alert.id);
        break;
      }
    }
  }

  @override
  Future<ScheduledAgentNotification?> markNotificationComplete(int id) async {
    final alerts = await _engine.query(includeDelivered: true);
    AiroAlert? target;
    for (final alert in alerts) {
      final alertIntId = int.tryParse(alert.id) ?? (alert.id.hashCode & 0x7fffffff);
      if (alertIntId == id || alert.id == id.toString()) {
        target = alert;
        break;
      }
    }
    if (target == null) return null;

    final updatedAlert = await _engine.markCompleted(target.id);
    if (updatedAlert == null) return null;
    return ScheduledAgentNotification.fromAiroAlert(updatedAlert);
  }

  @override
  Future<AgentNotificationPermissionStatus> notificationPermissionStatus() async {
    final status = await _engine.notificationPermissionStatus();
    switch (status) {
      case AiroNotificationPermissionStatus.enabled:
        return AgentNotificationPermissionStatus.enabled;
      case AiroNotificationPermissionStatus.disabled:
        return AgentNotificationPermissionStatus.disabled;
      case AiroNotificationPermissionStatus.unavailable:
        return AgentNotificationPermissionStatus.unavailable;
    }
  }

  @override
  Future<bool> requestNotificationPermission() async {
    return _engine.requestNotificationPermission();
  }

  DateTime _scheduledDateFor(ScheduleAgentNotificationRequest request) {
    final date = request.date;
    if (date != null && date.isNotEmpty) {
      final parsed = DateTime.parse(date);
      return DateTime(
        parsed.year,
        parsed.month,
        parsed.day,
        request.hour,
        request.minute,
      );
    }

    final now = DateTime.now();
    var scheduled = DateTime(
      now.year,
      now.month,
      now.day,
      request.hour,
      request.minute,
    );
    if (!request.repeatDaily && !scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
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
