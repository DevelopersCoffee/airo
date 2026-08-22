import 'package:core_domain/core_domain.dart';

import 'chat_entity_graph.dart';
import '../../../provenance/domain/models/extracted_entity.dart';

/// Maps between chat-local graph types and neutral `core_domain` contracts.
extension ChatEntityGraphBridge on ChatEntityGraph {
  EntityGraph toEntityGraph() => EntityGraph(
    nodes: nodes.map((node) => node.toEntityGraphNode()).toList(growable: false),
    edges: edges
        .map(
          (edge) => EntityGraphEdge(
            fromId: edge.fromId,
            toId: edge.toId,
            predicate: edge.predicate,
          ),
        )
        .toList(growable: false),
    recentNodeIds: recentNodeIds,
  );

  static ChatEntityGraph fromEntityGraph(EntityGraph graph) => ChatEntityGraph(
    nodes: graph.nodes
        .map(ChatGraphNodeBridge.fromEntityGraphNode)
        .toList(growable: false),
    edges: graph.edges
        .map(
          (edge) => ChatGraphEdge(
            fromId: edge.fromId,
            toId: edge.toId,
            predicate: edge.predicate,
          ),
        )
        .toList(growable: false),
    recentNodeIds: graph.recentNodeIds,
  );
}

extension ChatGraphNodeBridge on ChatGraphNode {
  EntityGraphNode toEntityGraphNode() => EntityGraphNode(
    id: id,
    typeKey: type.name,
    name: name,
    attributes: attributes,
  );

  static ChatGraphNode fromEntityGraphNode(EntityGraphNode node) => ChatGraphNode(
    id: node.id,
    type: EntityType.values.firstWhere(
      (item) => item.name == node.typeKey,
      orElse: () => EntityType.term,
    ),
    name: node.name,
    attributes: node.attributes,
  );
}
