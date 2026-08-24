import 'package:core_domain/core_domain.dart';

import '../../agent_chat/domain/models/chat_entity_graph.dart';
import '../../agent_chat/domain/models/entity_graph_bridge.dart';

/// Builds [EntityGraphPatch] deltas from chat-local graph ingest steps.
class LegacyWorkflowGraphPatch {
  const LegacyWorkflowGraphPatch._();

  static EntityGraphPatch delta(ChatEntityGraph before, ChatEntityGraph after) {
    final beforeGraph = before.toEntityGraph();
    final afterGraph = after.toEntityGraph();
    final beforeNodes = {for (final node in beforeGraph.nodes) node.id: node};
    final afterNodes = {for (final node in afterGraph.nodes) node.id: node};

    final nodes = <EntityGraphNode>[];
    for (final entry in afterNodes.entries) {
      final previous = beforeNodes[entry.key];
      if (previous == null || previous != entry.value) {
        nodes.add(entry.value);
      }
    }

    final beforeEdges = beforeGraph.edges.toSet();
    final edges = afterGraph.edges
        .where((edge) => !beforeEdges.contains(edge))
        .toList(growable: false);

    final mentioned = after.recentNodeIds
        .where((id) => !before.recentNodeIds.contains(id))
        .toList(growable: false);

    return EntityGraphPatch(
      nodes: nodes,
      edges: edges,
      mentionedNodeIds: mentioned,
    );
  }

  static ChatEntityGraph apply(ChatEntityGraph graph, EntityGraphPatch patch) {
    final merged = graph.toEntityGraph().merge(
      EntityGraph(
        nodes: patch.nodes,
        edges: patch.edges,
        recentNodeIds: patch.mentionedNodeIds,
      ),
    );
    return ChatEntityGraphBridge.fromEntityGraph(merged);
  }
}
