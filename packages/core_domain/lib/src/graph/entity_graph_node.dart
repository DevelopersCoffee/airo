import 'package:meta/meta.dart';

/// Neutral graph node contract. [typeKey] is an opaque validated string
/// (`person`, `organization`, `identifier`, …) — not a framework enum.
@immutable
class EntityGraphNode {
  const EntityGraphNode({
    required this.id,
    required this.typeKey,
    required this.name,
    this.attributes = const {},
  });

  final String id;
  final String typeKey;
  final String name;
  final Map<String, String> attributes;

  EntityGraphNode merge(EntityGraphNode other) {
    if (id != other.id) return this;
    return EntityGraphNode(
      id: id,
      typeKey: typeKey,
      name: other.name.length > name.length ? other.name : name,
      attributes: {...attributes, ...other.attributes},
    );
  }

  factory EntityGraphNode.fromJson(Map<String, dynamic> json) => EntityGraphNode(
    id: json['id'] as String,
    typeKey: json['type'] as String,
    name: json['name'] as String,
    attributes: ((json['attributes'] as Map?) ?? const {}).map(
      (key, value) => MapEntry(key.toString(), value.toString()),
    ),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': typeKey,
    'name': name,
    'attributes': attributes,
  };

  @override
  bool operator ==(Object other) =>
      other is EntityGraphNode &&
      other.id == id &&
      other.typeKey == typeKey &&
      other.name == name &&
      _mapEquals(other.attributes, attributes);

  @override
  int get hashCode => Object.hash(id, typeKey, name);

  static bool _mapEquals(Map<String, String> a, Map<String, String> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (a[key] != b[key]) return false;
    }
    return true;
  }
}
