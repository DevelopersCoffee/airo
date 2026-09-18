import 'package:equatable/equatable.dart';

class AiroTaskReference extends Equatable {
  const AiroTaskReference({
    required this.taskId,
    required this.action,
    this.dueAt,
    this.followUpPolicy = 'none',
    this.recurrence = 'none',
  });

  final String taskId;
  final String action;
  final DateTime? dueAt;
  final String followUpPolicy;
  final String recurrence;

  Map<String, Object?> toJson() {
    return {
      'task_id': taskId,
      'action': action,
      if (dueAt != null) 'due_at': dueAt!.toIso8601String(),
      'follow_up_policy': followUpPolicy,
      'recurrence': recurrence,
    };
  }

  factory AiroTaskReference.fromJson(Map<String, Object?> json) {
    return AiroTaskReference(
      taskId: json['task_id'] as String,
      action: json['action'] as String? ?? 'follow_up',
      dueAt: DateTime.tryParse(json['due_at'] as String? ?? ''),
      followUpPolicy: json['follow_up_policy'] as String? ?? 'none',
      recurrence: json['recurrence'] as String? ?? 'none',
    );
  }

  @override
  List<Object?> get props => [taskId, action, dueAt, followUpPolicy, recurrence];
}
