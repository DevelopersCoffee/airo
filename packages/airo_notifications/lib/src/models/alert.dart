import 'package:equatable/equatable.dart';

enum AiroAlertType {
  notification('notification'),
  reminder('reminder'),
  alert('alert'),
  task('task');

  const AiroAlertType(this.stableId);
  final String stableId;

  static AiroAlertType parse(String value) {
    return AiroAlertType.values.firstWhere(
      (e) => e.stableId == value,
      orElse: () => AiroAlertType.notification,
    );
  }
}

enum AiroDeliveryMode {
  immediate('immediate'),
  scheduled('scheduled'),
  condition('condition');

  const AiroDeliveryMode(this.stableId);
  final String stableId;

  static AiroDeliveryMode parse(String value) {
    return AiroDeliveryMode.values.firstWhere(
      (e) => e.stableId == value,
      orElse: () => AiroDeliveryMode.immediate,
    );
  }
}

enum AiroPriority {
  low('low'),
  normal('normal'),
  high('high'),
  critical('critical');

  const AiroPriority(this.stableId);
  final String stableId;

  static AiroPriority parse(String value) {
    return AiroPriority.values.firstWhere(
      (e) => e.stableId == value,
      orElse: () => AiroPriority.normal,
    );
  }
}

enum AiroAlertStatus {
  pending('pending'),
  delivered('delivered'),
  snoozed('snoozed'),
  dismissed('dismissed'),
  completed('completed');

  const AiroAlertStatus(this.stableId);
  final String stableId;

  static AiroAlertStatus parse(String value) {
    return AiroAlertStatus.values.firstWhere(
      (e) => e.stableId == value,
      orElse: () => AiroAlertStatus.pending,
    );
  }
}

class AiroAlert extends Equatable {
  AiroAlert({
    required this.id,
    required this.title,
    this.type = AiroAlertType.notification,
    this.delivery = AiroDeliveryMode.immediate,
    this.priority = AiroPriority.normal,
    this.status = AiroAlertStatus.pending,
    this.body,
    this.scheduledAt,
    this.timezone,
    this.groupId,
    this.taskId,
    this.source,
    this.snoozedUntil,
    this.repeatDaily = false,
    this.requiresCompletion = false,
    this.followUpPolicy = 'none',
    this.completedDates = const [],
    this.streakCount = 0,
    this.points = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, Object?> metadata = const {},
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        metadata = Map.unmodifiable(metadata);

  final String id;
  final AiroAlertType type;
  final AiroDeliveryMode delivery;
  final AiroPriority priority;
  final AiroAlertStatus status;
  final String title;
  final String? body;
  final DateTime? scheduledAt;
  final String? timezone;
  final String? groupId;
  final String? taskId;
  final String? source;
  final DateTime? snoozedUntil;
  final bool repeatDaily;
  final bool requiresCompletion;
  final String followUpPolicy;
  final List<String> completedDates;
  final int streakCount;
  final int points;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, Object?> metadata;

  AiroAlert copyWith({
    String? title,
    String? body,
    AiroAlertStatus? status,
    DateTime? scheduledAt,
    DateTime? snoozedUntil,
    bool? repeatDaily,
    bool? requiresCompletion,
    String? followUpPolicy,
    List<String>? completedDates,
    int? streakCount,
    int? points,
    DateTime? updatedAt,
    Map<String, Object?>? metadata,
  }) {
    return AiroAlert(
      id: id,
      title: title ?? this.title,
      type: type,
      delivery: delivery,
      priority: priority,
      status: status ?? this.status,
      body: body ?? this.body,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      timezone: timezone,
      groupId: groupId,
      taskId: taskId,
      source: source,
      snoozedUntil: snoozedUntil ?? this.snoozedUntil,
      repeatDaily: repeatDaily ?? this.repeatDaily,
      requiresCompletion: requiresCompletion ?? this.requiresCompletion,
      followUpPolicy: followUpPolicy ?? this.followUpPolicy,
      completedDates: completedDates ?? this.completedDates,
      streakCount: streakCount ?? this.streakCount,
      points: points ?? this.points,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'type': type.stableId,
      'delivery': delivery.stableId,
      'priority': priority.stableId,
      'status': status.stableId,
      'title': title,
      if (body != null) 'body': body,
      if (scheduledAt != null) 'scheduled_at': scheduledAt!.toIso8601String(),
      if (timezone != null) 'timezone': timezone,
      if (groupId != null) 'group_id': groupId,
      if (taskId != null) 'task_id': taskId,
      if (source != null) 'source': source,
      if (snoozedUntil != null) 'snoozed_until': snoozedUntil!.toIso8601String(),
      'repeat_daily': repeatDaily,
      'requires_completion': requiresCompletion,
      'follow_up_policy': followUpPolicy,
      'completed_dates': completedDates,
      'streak_count': streakCount,
      'points': points,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      if (metadata.isNotEmpty) 'metadata': metadata,
    };
  }

  factory AiroAlert.fromJson(Map<String, Object?> json) {
    final rawId = json['id'];
    final idStr = rawId != null ? rawId.toString() : '';
    final bodyStr = (json['body'] as String?) ?? (json['message'] as String?);
    final schedStr = (json['scheduled_at'] as String?) ?? (json['scheduledAt'] as String?);
    final createdStr = (json['created_at'] as String?) ?? (json['createdAt'] as String?);
    final updatedStr = (json['updated_at'] as String?) ?? (json['updatedAt'] as String?);
    final snoozedStr = (json['snoozed_until'] as String?) ?? (json['snoozedUntil'] as String?);

    return AiroAlert(
      id: idStr,
      title: json['title'] as String? ?? '',
      type: AiroAlertType.parse(json['type'] as String? ?? json['schedule_type'] as String? ?? ''),
      delivery: AiroDeliveryMode.parse(json['delivery'] as String? ?? ''),
      priority: AiroPriority.parse(json['priority'] as String? ?? ''),
      status: AiroAlertStatus.parse(json['status'] as String? ?? ''),
      body: bodyStr,
      scheduledAt: DateTime.tryParse(schedStr ?? ''),
      timezone: json['timezone'] as String?,
      groupId: (json['group_id'] as String?) ?? (json['groupId'] as String?),
      taskId: (json['task_id'] as String?) ?? (json['taskId'] as String?),
      source: json['source'] as String?,
      snoozedUntil: DateTime.tryParse(snoozedStr ?? ''),
      repeatDaily: json['repeat_daily'] as bool? ?? json['repeatDaily'] as bool? ?? false,
      requiresCompletion: json['requires_completion'] as bool? ?? json['requiresCompletion'] as bool? ?? false,
      followUpPolicy: (json['follow_up_policy'] as String?) ?? (json['followUpPolicy'] as String?) ?? 'none',
      completedDates:
          (json['completed_dates'] as List?)?.whereType<String>().toList() ??
          (json['completedDates'] as List?)?.whereType<String>().toList() ??
          const [],
      streakCount: json['streak_count'] as int? ?? json['streakCount'] as int? ?? 0,
      points: json['points'] as int? ?? json['points'] as int? ?? 0,
      createdAt: DateTime.tryParse(createdStr ?? ''),
      updatedAt: DateTime.tryParse(updatedStr ?? ''),
      metadata: (json['metadata'] as Map?)?.cast<String, Object?>() ?? const {},
    );
  }

  @override
  List<Object?> get props => [
        id,
        type,
        delivery,
        priority,
        status,
        title,
        body,
        scheduledAt,
        timezone,
        groupId,
        taskId,
        source,
        snoozedUntil,
        repeatDaily,
        requiresCompletion,
        followUpPolicy,
        completedDates,
        streakCount,
        points,
        createdAt,
        updatedAt,
        metadata,
      ];
}
