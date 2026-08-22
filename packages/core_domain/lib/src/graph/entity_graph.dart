import 'package:meta/meta.dart';

import 'entity_graph_edge.dart';
import 'entity_graph_node.dart';

/// Immutable graph snapshot. JSON shape matches the chat entity graph store.
@immutable
class EntityGraph {
  const EntityGraph({
    this.nodes = const [],
    this.edges = const [],
    this.recentNodeIds = const [],
  });

  final List<EntityGraphNode> nodes;
  final List<EntityGraphEdge> edges;
  final List<String> recentNodeIds;

  static const empty = EntityGraph();

  EntityGraphNode? nodeById(String id) {
    for (final node in nodes) {
      if (node.id == id) return node;
    }
    return null;
  }

  EntityGraph merge(EntityGraph other) => upsert(
    incomingNodes: other.nodes,
    incomingEdges: other.edges,
    mentionedIds: other.recentNodeIds,
  );

  EntityGraph upsert({
    required List<EntityGraphNode> incomingNodes,
    required List<EntityGraphEdge> incomingEdges,
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
    return EntityGraph(
      nodes: byId.values.toList(growable: false),
      edges: edgeSet.toList(growable: false),
      recentNodeIds: recent.take(12).toList(growable: false),
    );
  }

  factory EntityGraph.fromJson(Map<String, dynamic> json) => EntityGraph(
    nodes: ((json['nodes'] as List?) ?? const [])
        .map((item) => EntityGraphNode.fromJson(item as Map<String, dynamic>))
        .toList(growable: false),
    edges: ((json['edges'] as List?) ?? const [])
        .map((item) => EntityGraphEdge.fromJson(item as Map<String, dynamic>))
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

  EntityGraph withNodeAttribute(String nodeId, String key, String value) {
    final updated = nodes
        .map((node) {
          if (node.id != nodeId) return node;
          return node.merge(
            EntityGraphNode(
              id: node.id,
              typeKey: node.typeKey,
              name: node.name,
              attributes: {key: value},
            ),
          );
        })
        .toList(growable: false);
    return EntityGraph(
      nodes: updated,
      edges: edges,
      recentNodeIds: recentNodeIds,
    );
  }

  Iterable<EntityGraphEdge> edgesFor(String nodeId) =>
      edges.where((edge) => edge.fromId == nodeId || edge.toId == nodeId);
}
