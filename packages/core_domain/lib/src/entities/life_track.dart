import 'package:meta/meta.dart';

import 'entity.dart';
import 'milestone.dart';

enum LifeTrackCategory {
  realEstate,
  education,
  medical,
  insurance,
  finance,
  travel,
  carPurchase,
  legal,
  custom,
}

enum TrackStatus { draft, active, completed, archived, postponed }

enum ItemStatus { todo, inProgress, blocked, done, skipped }

enum FieldType { text, date, document, link, boolean, number }

@immutable
class LifeTrack extends Entity {
  const LifeTrack({
    required super.id,
    required this.title,
    required this.category,
    required this.status,
    required this.milestones,
    required this.createdAt,
    required this.updatedAt,
    this.templateId,
  });

  final String title;
  final LifeTrackCategory category;
  final TrackStatus status;
  final List<Milestone> milestones;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? templateId;

  double get progress {
    var completed = 0;
    var total = 0;

    for (final milestone in milestones) {
      for (final item in milestone.actionItems) {
        if (item.status == ItemStatus.skipped) continue;
        total++;
        if (item.status == ItemStatus.done) {
          completed++;
        }
      }
    }

    if (total == 0) return 0;
    return completed / total;
  }

  factory LifeTrack.fromJson(Map<String, dynamic> json) => LifeTrack(
    id: json['id'] as String,
    title: json['title'] as String,
    category: _lifeTrackCategoryFromJson(json['category'] as String),
    status: _trackStatusFromJson(json['status'] as String),
    milestones: ((json['milestones'] as List?) ?? const [])
        .map((item) => Milestone.fromJson(item as Map<String, dynamic>))
        .toList(growable: false),
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
    templateId: json['template_id'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'category': category.name,
    'status': status.name,
    'milestones': milestones
        .map((milestone) => milestone.toJson())
        .toList(growable: false),
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'template_id': templateId,
    'progress': progress,
  };

  LifeTrack copyWith({
    String? id,
    String? title,
    LifeTrackCategory? category,
    TrackStatus? status,
    List<Milestone>? milestones,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? templateId,
  }) => LifeTrack(
    id: id ?? this.id,
    title: title ?? this.title,
    category: category ?? this.category,
    status: status ?? this.status,
    milestones: milestones ?? this.milestones,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    templateId: templateId ?? this.templateId,
  );

  @override
  List<Object?> get props => [
    ...super.props,
    title,
    category,
    status,
    milestones,
    createdAt,
    updatedAt,
    templateId,
  ];
}

LifeTrackCategory _lifeTrackCategoryFromJson(String value) =>
    LifeTrackCategory.values.firstWhere((item) => item.name == value);

TrackStatus _trackStatusFromJson(String value) =>
    TrackStatus.values.firstWhere((item) => item.name == value);
