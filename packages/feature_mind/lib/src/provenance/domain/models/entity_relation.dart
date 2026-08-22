import 'package:flutter/foundation.dart';

import 'extracted_entity.dart';

/// Closed set of on-device relation kinds. Same reason as [EntityType]:
/// the inspector can only render kinds we named on purpose.
enum EntityRelationKind { worksAt, locatedIn, announcedOn, valuedAt }

/// One typed link between two already-extracted entities.
@immutable
class EntityRelation {
  const EntityRelation({
    required this.from,
    required this.kind,
    required this.to,
  });

  final ExtractedEntity from;
  final EntityRelationKind kind;
  final ExtractedEntity to;

  String get label => switch (kind) {
    EntityRelationKind.worksAt => 'works at',
    EntityRelationKind.locatedIn => 'located in',
    EntityRelationKind.announcedOn => 'announced on',
    EntityRelationKind.valuedAt => 'valued at',
  };

  Map<String, Object> toJson() => {
    'from': from.toJson(),
    'kind': kind.name,
    'to': to.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      other is EntityRelation &&
      other.from == from &&
      other.kind == kind &&
      other.to == to;

  @override
  int get hashCode => Object.hash(from, kind, to);

  @override
  String toString() => '${from.text} · $label · ${to.text}';
}

/// Entities plus the relations inferred from one text span.
@immutable
class EntityRelationGraph {
  const EntityRelationGraph({
    this.entities = const [],
    this.relations = const [],
  });

  static const empty = EntityRelationGraph();

  final List<ExtractedEntity> entities;
  final List<EntityRelation> relations;

  Map<String, Object> toJson() => {
    'entities': entities.toJson(),
    'relations': [for (final relation in relations) relation.toJson()],
  };
}
