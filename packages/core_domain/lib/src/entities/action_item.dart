import 'package:meta/meta.dart';

import 'input_requirement.dart';
import 'life_track.dart';

@immutable
class ActionItem {
  const ActionItem({
    required this.id,
    required this.milestoneId,
    required this.summary,
    required this.status,
    required this.requirements,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.dueDate,
    this.notes,
  });

  final String id;
  final String milestoneId;
  final String summary;
  final String? description;
  final ItemStatus status;
  final List<InputRequirement> requirements;
  final DateTime? dueDate;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory ActionItem.fromJson(Map<String, dynamic> json) => ActionItem(
    id: json['id'] as String,
    milestoneId: json['milestone_id'] as String,
    summary: json['summary'] as String,
    description: json['description'] as String?,
    status: _itemStatusFromJson(json['status'] as String),
    requirements: ((json['requirements'] as List?) ?? const [])
        .map((item) => InputRequirement.fromJson(item as Map<String, dynamic>))
        .toList(growable: false),
    dueDate: json['due_date'] == null
        ? null
        : DateTime.parse(json['due_date'] as String),
    notes: json['notes'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'milestone_id': milestoneId,
    'summary': summary,
    'description': description,
    'status': status.name,
    'requirements': requirements
        .map((item) => item.toJson())
        .toList(growable: false),
    'due_date': dueDate?.toIso8601String(),
    'notes': notes,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  ActionItem copyWith({
    String? id,
    String? milestoneId,
    String? summary,
    String? description,
    ItemStatus? status,
    List<InputRequirement>? requirements,
    DateTime? dueDate,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => ActionItem(
    id: id ?? this.id,
    milestoneId: milestoneId ?? this.milestoneId,
    summary: summary ?? this.summary,
    description: description ?? this.description,
    status: status ?? this.status,
    requirements: requirements ?? this.requirements,
    dueDate: dueDate ?? this.dueDate,
    notes: notes ?? this.notes,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ActionItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          milestoneId == other.milestoneId &&
          summary == other.summary &&
          description == other.description &&
          status == other.status &&
          _listEquals(requirements, other.requirements) &&
          dueDate == other.dueDate &&
          notes == other.notes &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(
    id,
    milestoneId,
    summary,
    description,
    status,
    Object.hashAll(requirements),
    dueDate,
    notes,
    createdAt,
    updatedAt,
  );
}

ItemStatus _itemStatusFromJson(String value) =>
    ItemStatus.values.firstWhere((item) => item.name == value);

bool _listEquals<T>(List<T> left, List<T> right) {
  if (identical(left, right)) return true;
  if (left.length != right.length) return false;
  for (var i = 0; i < left.length; i++) {
    if (left[i] != right[i]) return false;
  }
  return true;
}
