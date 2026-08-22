import 'package:meta/meta.dart';

@immutable
class EntityGraphEdge {
  const EntityGraphEdge({
    required this.fromId,
    required this.toId,
    required this.predicate,
  });

  final String fromId;
  final String toId;
  final String predicate;

  factory EntityGraphEdge.fromJson(Map<String, dynamic> json) =>
      EntityGraphEdge(
        fromId: json['from_id'] as String,
        toId: json['to_id'] as String,
        predicate: json['predicate'] as String,
      );

  Map<String, dynamic> toJson() => {
    'from_id': fromId,
    'to_id': toId,
    'predicate': predicate,
  };

  @override
  bool operator ==(Object other) =>
      other is EntityGraphEdge &&
      other.fromId == fromId &&
      other.toId == toId &&
      other.predicate == predicate;

  @override
  int get hashCode => Object.hash(fromId, toId, predicate);
}
