import 'package:core_domain/core_domain.dart';
import 'package:meta/meta.dart';

/// Template entity - replace with your actual entity
@immutable
class TemplateEntity extends Entity {
  const TemplateEntity({
    required super.id,
    required this.name,
    this.description,
    this.createdAt,
  });

  final String name;
  final String? description;
  final DateTime? createdAt;

  @override
  List<Object?> get props => [...super.props, name, description, createdAt];

  TemplateEntity copyWith({
    String? id,
    String? name,
    String? description,
    DateTime? createdAt,
  }) =>
      TemplateEntity(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description ?? this.description,
        createdAt: createdAt ?? this.createdAt,
      );
}

