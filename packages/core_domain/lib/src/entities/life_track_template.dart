import 'package:meta/meta.dart';

import 'life_track.dart';

@immutable
class LifeTrackTemplate {
  const LifeTrackTemplate({
    required this.templateId,
    required this.title,
    required this.description,
    required this.category,
    required this.version,
    required this.milestones,
  });

  final String templateId;
  final String title;
  final String description;
  final LifeTrackCategory category;
  final String version;
  final List<MilestoneTemplate> milestones;

  factory LifeTrackTemplate.fromJson(Map<String, dynamic> json) =>
      LifeTrackTemplate(
        templateId: json['template_id'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        category: LifeTrackCategory.values.firstWhere(
          (item) => item.name == json['category'],
        ),
        version: json['version'] as String,
        milestones: ((json['milestones'] as List?) ?? const [])
            .map(
              (item) =>
                  MilestoneTemplate.fromJson(item as Map<String, dynamic>),
            )
            .toList(growable: false),
      );

  Map<String, dynamic> toJson() => {
    'template_id': templateId,
    'title': title,
    'description': description,
    'category': category.name,
    'version': version,
    'milestones': milestones
        .map((item) => item.toJson())
        .toList(growable: false),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LifeTrackTemplate &&
          runtimeType == other.runtimeType &&
          templateId == other.templateId &&
          title == other.title &&
          description == other.description &&
          category == other.category &&
          version == other.version &&
          _listEquals(milestones, other.milestones);

  @override
  int get hashCode => Object.hash(
    templateId,
    title,
    description,
    category,
    version,
    Object.hashAll(milestones),
  );
}

@immutable
class MilestoneTemplate {
  const MilestoneTemplate({
    required this.name,
    required this.objective,
    required this.tasks,
  });

  final String name;
  final String objective;
  final List<ActionItemTemplate> tasks;

  factory MilestoneTemplate.fromJson(Map<String, dynamic> json) =>
      MilestoneTemplate(
        name: json['name'] as String,
        objective: json['objective'] as String,
        tasks: ((json['tasks'] as List?) ?? const [])
            .map(
              (item) =>
                  ActionItemTemplate.fromJson(item as Map<String, dynamic>),
            )
            .toList(growable: false),
      );

  Map<String, dynamic> toJson() => {
    'name': name,
    'objective': objective,
    'tasks': tasks.map((item) => item.toJson()).toList(growable: false),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MilestoneTemplate &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          objective == other.objective &&
          _listEquals(tasks, other.tasks);

  @override
  int get hashCode => Object.hash(name, objective, Object.hashAll(tasks));
}

@immutable
class ActionItemTemplate {
  const ActionItemTemplate({
    required this.summary,
    this.description,
    required this.requirements,
  });

  final String summary;
  final String? description;
  final List<InputRequirementTemplate> requirements;

  factory ActionItemTemplate.fromJson(Map<String, dynamic> json) =>
      ActionItemTemplate(
        summary: json['summary'] as String,
        description: json['description'] as String?,
        requirements: ((json['requirements'] as List?) ?? const [])
            .map(
              (item) => InputRequirementTemplate.fromJson(
                item as Map<String, dynamic>,
              ),
            )
            .toList(growable: false),
      );

  Map<String, dynamic> toJson() => {
    'summary': summary,
    'description': description,
    'requirements': requirements
        .map((item) => item.toJson())
        .toList(growable: false),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ActionItemTemplate &&
          runtimeType == other.runtimeType &&
          summary == other.summary &&
          description == other.description &&
          _listEquals(requirements, other.requirements);

  @override
  int get hashCode =>
      Object.hash(summary, description, Object.hashAll(requirements));
}

@immutable
class InputRequirementTemplate {
  const InputRequirementTemplate({
    required this.label,
    required this.type,
    required this.isRequired,
    this.hint,
  });

  final String label;
  final FieldType type;
  final bool isRequired;
  final String? hint;

  factory InputRequirementTemplate.fromJson(Map<String, dynamic> json) =>
      InputRequirementTemplate(
        label: json['label'] as String,
        type: FieldType.values.firstWhere((item) => item.name == json['type']),
        isRequired: json['is_required'] as bool? ?? false,
        hint: json['hint'] as String?,
      );

  Map<String, dynamic> toJson() => {
    'label': label,
    'type': type.name,
    'is_required': isRequired,
    'hint': hint,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InputRequirementTemplate &&
          runtimeType == other.runtimeType &&
          label == other.label &&
          type == other.type &&
          isRequired == other.isRequired &&
          hint == other.hint;

  @override
  int get hashCode => Object.hash(label, type, isRequired, hint);
}

bool _listEquals<T>(List<T> left, List<T> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
