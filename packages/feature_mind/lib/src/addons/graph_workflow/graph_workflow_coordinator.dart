import 'package:core_ai/core_ai.dart';
import 'package:core_domain/core_domain.dart';

import '../../agent_chat/domain/models/chat_entity_graph.dart';
import '../../agent_chat/domain/models/entity_graph_bridge.dart';
import '../../agent_chat/domain/services/chat_entity_graph_pending.dart';
import '../../agent_chat/domain/services/projected_chat_journey.dart';
import 'legacy_chat_entity_linker.dart';
import 'legacy_workflow_graph_patch.dart';
import 'graph_workflow_projection_bridge.dart';

/// Routes graph-workflow add-ons through the registry without host ID switches.
class GraphWorkflowCoordinator {
  GraphWorkflowCoordinator(
    this._registry, {
    LegacyChatEntityLinker linker = const LegacyChatEntityLinker(),
    GraphWorkflowProjectionBridge projectionBridge =
        const GraphWorkflowProjectionBridge(),
    ChatEntityGraphPending? pending,
  }) : _legacyLinker = linker,
       _projectionBridge = projectionBridge,
       _pending = pending ?? ChatEntityGraphPending();

  final AddonRegistry _registry;
  final LegacyChatEntityLinker _legacyLinker;
  final GraphWorkflowProjectionBridge _projectionBridge;
  final ChatEntityGraphPending _pending;

  bool shouldIngest(String text, ChatEntityGraph graph) {
    if (text.trim().isEmpty) return false;
    final context = GraphIngestContext(
      text: text,
      graph: graph.toEntityGraph(),
    );
    return _registry.eligibleGraphAdapters().any((adapter) => adapter.accepts(context));
  }

  ChatEntityGraph ingest(ChatEntityGraph graph, String text) {
    if (!shouldIngest(text, graph)) return graph;
    return _legacyLinker.ingest(graph, text);
  }

  Future<ChatEntityGraph> ingestWithAddonPatches(
    ChatEntityGraph graph,
    String text,
  ) async {
    if (!shouldIngest(text, graph)) return graph;
    var chatGraph = graph;
    var entityGraph = chatGraph.toEntityGraph();
    var context = GraphIngestContext(text: text, graph: entityGraph);
    for (final adapter in _registry.eligibleGraphAdapters()) {
      if (!adapter.accepts(context)) continue;
      final patch = await adapter.extract(context);
      if (patch.isEmpty) continue;
      chatGraph = LegacyWorkflowGraphPatch.apply(chatGraph, patch);
      entityGraph = chatGraph.toEntityGraph();
      context = GraphIngestContext(text: text, graph: entityGraph);
    }
    chatGraph = _legacyLinker.ingestGenericMentions(chatGraph, text);
    return chatGraph;
  }

  List<ProjectedChatJourney> projectJourneys(ChatEntityGraph graph) =>
      _projectionBridge.projectChatJourneys(graph);

  ProjectedChatJourney? firstUnofferedJourney(ChatEntityGraph graph) {
    for (final projection in workflowProjections(graph)) {
      if (projection.offer.kind != OfferDecisionKind.offerable) continue;
      final node = graph.nodeById(projection.subjectNodeId);
      if (node?.attributes['journey_offered'] == 'true') continue;
      return ProjectedChatJourney(
        subjectNodeId: projection.subjectNodeId,
        templateId: projection.templateId,
        title: projection.title,
        facts: Map<String, String>.from(projection.factsByFieldId),
      );
    }
    return null;
  }

  List<WorkflowProjection> workflowProjections(ChatEntityGraph graph) {
    final entityGraph = graph.toEntityGraph();
    final projections = <WorkflowProjection>[];
    for (final adapter in _registry.eligibleGraphAdapters()) {
      projections.addAll(adapter.project(entityGraph));
    }
    return projections;
  }

  String formatPending({
    required ChatEntityGraph graph,
    required String query,
  }) => _pending.format(graph: graph, query: query);

  bool wantsPending(String query) => _pending.wantsPending(query);
}
