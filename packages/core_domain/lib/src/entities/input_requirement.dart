import 'package:meta/meta.dart';

import 'life_track.dart';

@immutable
class InputRequirement {
  const InputRequirement({
    required this.id,
    required this.actionItemId,
    required this.label,
    required this.fieldType,
    required this.isRequired,
    this.value,
    this.hint,
  });

  final String id;
  final String actionItemId;
  final String label;
  final FieldType fieldType;
  final String? value;
  final bool isRequired;
  final String? hint;

  factory InputRequirement.fromJson(Map<String, dynamic> json) =>
      InputRequirement(
        id: json['id'] as String,
        actionItemId: json['action_item_id'] as String,
        label: json['label'] as String,
        fieldType: _fieldTypeFromJson(json['field_type'] as String),
        value: json['value'] as String?,
        isRequired: json['is_required'] as bool,
        hint: json['hint'] as String?,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'action_item_id': actionItemId,
    'label': label,
    'field_type': fieldType.name,
    'value': value,
    'is_required': isRequired,
    'hint': hint,
  };

  InputRequirement copyWith({
    String? id,
    String? actionItemId,
    String? label,
    FieldType? fieldType,
    String? value,
    bool? isRequired,
    String? hint,
  }) => InputRequirement(
    id: id ?? this.id,
    actionItemId: actionItemId ?? this.actionItemId,
    label: label ?? this.label,
    fieldType: fieldType ?? this.fieldType,
    value: value ?? this.value,
    isRequired: isRequired ?? this.isRequired,
    hint: hint ?? this.hint,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InputRequirement &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          actionItemId == other.actionItemId &&
          label == other.label &&
          fieldType == other.fieldType &&
          value == other.value &&
          isRequired == other.isRequired &&
          hint == other.hint;

  @override
  int get hashCode =>
      Object.hash(id, actionItemId, label, fieldType, value, isRequired, hint);
}

FieldType _fieldTypeFromJson(String value) =>
    FieldType.values.firstWhere((item) => item.name == value);
