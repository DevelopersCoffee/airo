import 'package:equatable/equatable.dart';

enum AiroNotificationActionType {
  open('open'),
  complete('complete'),
  snooze('snooze'),
  dismiss('dismiss');

  const AiroNotificationActionType(this.stableId);
  final String stableId;

  static AiroNotificationActionType parse(String value) {
    return AiroNotificationActionType.values.firstWhere(
      (e) => e.stableId == value,
      orElse: () => AiroNotificationActionType.open,
    );
  }
}

class AiroNotificationAction extends Equatable {
  const AiroNotificationAction({
    required this.actionId,
    required this.label,
    this.type = AiroNotificationActionType.open,
    this.snoozeDuration = const Duration(minutes: 30),
    this.payload,
  });

  final String actionId;
  final String label;
  final AiroNotificationActionType type;
  final Duration snoozeDuration;
  final String? payload;

  Map<String, Object?> toJson() {
    return {
      'action_id': actionId,
      'label': label,
      'type': type.stableId,
      'snooze_duration_ms': snoozeDuration.inMilliseconds,
      if (payload != null) 'payload': payload,
    };
  }

  factory AiroNotificationAction.fromJson(Map<String, Object?> json) {
    return AiroNotificationAction(
      actionId: json['action_id'] as String,
      label: json['label'] as String? ?? '',
      type: AiroNotificationActionType.parse(json['type'] as String? ?? ''),
      snoozeDuration: Duration(
        milliseconds: json['snooze_duration_ms'] as int? ?? 1800000,
      ),
      payload: json['payload'] as String?,
    );
  }

  @override
  List<Object?> get props => [actionId, label, type, snoozeDuration, payload];
}

class AiroNotificationActionEvent extends Equatable {
  const AiroNotificationActionEvent({
    required this.alertId,
    required this.action,
    this.taskId,
    this.snoozeDuration,
    this.timestamp,
  });

  final String alertId;
  final AiroNotificationActionType action;
  final String? taskId;
  final Duration? snoozeDuration;
  final DateTime? timestamp;

  @override
  List<Object?> get props => [alertId, action, taskId, snoozeDuration, timestamp];
}
