import 'package:meta/meta.dart';

import '../../../provenance/domain/models/extracted_entity.dart';

/// One node in the chat memory graph. Identity is [id], which is stable across
/// mentions so "Niva Bupa" in a later message is the same organization.
@immutable
class ChatGraphNode {
  const ChatGraphNode({
    required this.id,
    required this.type,
    required this.name,
    this.attributes = const {},
  });

  final String id;
  final EntityType type;
  final String name;
  final Map<String, String> attributes;

  ChatGraphNode merge(ChatGraphNode other) {
    if (id != other.id) return this;
    return ChatGraphNode(
      id: id,
      type: type,
      name: other.name.length > name.length ? other.name : name,
      attributes: {...attributes, ...other.attributes},
    );
  }

  factory ChatGraphNode.fromJson(Map<String, dynamic> json) => ChatGraphNode(
    id: json['id'] as String,
    type: EntityType.values.firstWhere(
      (item) => item.name == json['type'],
      orElse: () => EntityType.term,
    ),
    name: json['name'] as String,
    attributes: ((json['attributes'] as Map?) ?? const {}).map(
      (key, value) => MapEntry(key.toString(), value.toString()),
    ),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'name': name,
    'attributes': attributes,
  };

  @override
  bool operator ==(Object other) =>
      other is ChatGraphNode &&
      other.id == id &&
      other.type == type &&
      other.name == name;

  @override
  int get hashCode => Object.hash(id, type, name);
}

/// A typed edge. The same hospital bill can have many of these at once —
/// insurance, tax, hospital — because the graph is not a tree.
@immutable
class ChatGraphEdge {
  const ChatGraphEdge({
    required this.fromId,
    required this.toId,
    required this.predicate,
  });

  final String fromId;
  final String toId;
  final String predicate;

  factory ChatGraphEdge.fromJson(Map<String, dynamic> json) => ChatGraphEdge(
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
      other is ChatGraphEdge &&
      other.fromId == fromId &&
      other.toId == toId &&
      other.predicate == predicate;

  @override
  int get hashCode => Object.hash(fromId, toId, predicate);
}

class ChatEntityRelation {
  static const insuredBy = 'insured_by';
  static const filedVia = 'filed_via';
  static const hasDocument = 'has_document';
  static const relatedTo = 'related_to';
  static const mentionedWith = 'mentioned_with';
}

@immutable
class ChatEntityGraph {
  const ChatEntityGraph({
    this.nodes = const [],
    this.edges = const [],
    this.recentNodeIds = const [],
  });

  final List<ChatGraphNode> nodes;
  final List<ChatGraphEdge> edges;
  final List<String> recentNodeIds;

  static const empty = ChatEntityGraph();

  ChatGraphNode? nodeById(String id) {
    for (final node in nodes) {
      if (node.id == id) return node;
    }
    return null;
  }

  ChatEntityGraph upsert({
    required List<ChatGraphNode> incomingNodes,
    required List<ChatGraphEdge> incomingEdges,
    required List<String> mentionedIds,
  }) {
    final byId = {for (final node in nodes) node.id: node};
    for (final node in incomingNodes) {
      final existing = byId[node.id];
      byId[node.id] = existing == null ? node : existing.merge(node);
    }
    final edgeSet = {...edges, ...incomingEdges};
    final recent = [
      ...mentionedIds,
      ...recentNodeIds,
    ].where(byId.containsKey).toSet().toList(growable: false);
    return ChatEntityGraph(
      nodes: byId.values.toList(growable: false),
      edges: edgeSet.toList(growable: false),
      recentNodeIds: recent.take(12).toList(growable: false),
    );
  }

  factory ChatEntityGraph.fromJson(Map<String, dynamic> json) =>
      ChatEntityGraph(
        nodes: ((json['nodes'] as List?) ?? const [])
            .map((item) => ChatGraphNode.fromJson(item as Map<String, dynamic>))
            .toList(growable: false),
        edges: ((json['edges'] as List?) ?? const [])
            .map((item) => ChatGraphEdge.fromJson(item as Map<String, dynamic>))
            .toList(growable: false),
        recentNodeIds: ((json['recent_node_ids'] as List?) ?? const [])
            .map((item) => item.toString())
            .toList(growable: false),
      );

  Map<String, dynamic> toJson() => {
    'nodes': nodes.map((node) => node.toJson()).toList(growable: false),
    'edges': edges.map((edge) => edge.toJson()).toList(growable: false),
    'recent_node_ids': recentNodeIds,
  };

  ChatEntityGraph withNodeAttribute(String nodeId, String key, String value) {
    final updated = nodes
        .map((node) {
          if (node.id != nodeId) return node;
          return node.merge(
            ChatGraphNode(
              id: node.id,
              type: node.type,
              name: node.name,
              attributes: {key: value},
            ),
          );
        })
        .toList(growable: false);
    return ChatEntityGraph(
      nodes: updated,
      edges: edges,
      recentNodeIds: recentNodeIds,
    );
  }

  Iterable<ChatGraphEdge> edgesFor(String nodeId) =>
      edges.where((edge) => edge.fromId == nodeId || edge.toId == nodeId);
}
