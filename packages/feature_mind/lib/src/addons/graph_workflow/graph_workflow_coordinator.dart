import 'package:core_ai/core_ai.dart';
import 'package:core_domain/core_domain.dart';

import '../../agent_chat/domain/models/chat_entity_graph.dart';
import '../../agent_chat/domain/models/entity_graph_bridge.dart';
import '../../agent_chat/domain/services/chat_entity_graph_pending.dart';
import '../../agent_chat/domain/services/projected_chat_journey.dart';
import 'legacy_chat_entity_linker.dart';
import 'legacy_workflow_graph_patch.dart';
import 'graph_ingest_result.dart';

/// Routes graph-workflow add-ons through the registry without host ID switches.
class GraphWorkflowCoordinator {
  GraphWorkflowCoordinator(
    this._registry, {
    LegacyChatEntityLinker linker = const LegacyChatEntityLinker(),
    ChatEntityGraphPending? pending,
  }) : _legacyLinker = linker,
       _pending = pending ?? ChatEntityGraphPending();

  final AddonRegistry _registry;
  final LegacyChatEntityLinker _legacyLinker;
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

  Future<GraphIngestResult> ingestWithAddonPatches(
    ChatEntityGraph graph,
    String text,
  ) async {
    if (!shouldIngest(text, graph)) {
      return GraphIngestResult.success(graph);
    }
    final invocationEpoch = _registry.invocationEpoch;
    var chatGraph = graph;
    var entityGraph = chatGraph.toEntityGraph();
    var context = GraphIngestContext(text: text, graph: entityGraph);
    for (final adapter in _registry.eligibleGraphAdapters()) {
      if (_registry.invocationEpoch != invocationEpoch) {
        return GraphIngestResult.cancelled(graph);
      }
      if (!adapter.accepts(context)) continue;
      final patch = await adapter.extract(context);
      if (_registry.invocationEpoch != invocationEpoch) {
        return GraphIngestResult.cancelled(graph);
      }
      if (patch.isEmpty) continue;
      chatGraph = LegacyWorkflowGraphPatch.apply(chatGraph, patch);
      entityGraph = chatGraph.toEntityGraph();
      context = GraphIngestContext(text: text, graph: entityGraph);
    }
    if (_registry.invocationEpoch != invocationEpoch) {
      return GraphIngestResult.cancelled(graph);
    }
    chatGraph = _legacyLinker.ingestGenericMentions(chatGraph, text);
    return GraphIngestResult.success(chatGraph);
  }

  List<ProjectedChatJourney> projectJourneys(ChatEntityGraph graph) {
    return workflowProjections(graph)
        .map(ProjectedChatJourney.fromWorkflowProjection)
        .toList(growable: false);
  }

  ProjectedChatJourney? firstUnofferedJourney(ChatEntityGraph graph) {
    for (final projection in workflowProjections(graph)) {
      if (projection.offer.kind != OfferDecisionKind.offerable) continue;
      final node = graph.nodeById(projection.subjectNodeId);
      if (node?.attributes['journey_offered'] == 'true') continue;
      return ProjectedChatJourney.fromWorkflowProjection(projection);
    }
    return null;
  }

  List<WorkflowProjection> workflowProjections(ChatEntityGraph graph) {
    final invocationEpoch = _registry.invocationEpoch;
    final entityGraph = graph.toEntityGraph();
    final projections = <WorkflowProjection>[];
    for (final adapter in _registry.eligibleGraphAdapters()) {
      if (_registry.invocationEpoch != invocationEpoch) break;
      projections.addAll(adapter.project(entityGraph));
    }
    return projections;
  }

  Map<String, PendingAssessment> pendingAssessments(ChatEntityGraph graph) {
    final invocationEpoch = _registry.invocationEpoch;
    final entityGraph = graph.toEntityGraph();
    final assessments = <String, PendingAssessment>{};
    for (final adapter in _registry.eligibleGraphAdapters()) {
      if (_registry.invocationEpoch != invocationEpoch) break;
      for (final projection in adapter.project(entityGraph)) {
        if (_registry.invocationEpoch != invocationEpoch) break;
        assessments[projection.subjectNodeId] = adapter.assessPending(
          entityGraph,
          projection,
        );
      }
    }
    return assessments;
  }

  String formatPending({
    required ChatEntityGraph graph,
    required String query,
  }) {
    final projections = workflowProjections(graph);
    return _pending.format(
      graph: graph,
      query: query,
      projections: projections,
      assessments: pendingAssessments(graph),
    );
  }

  bool wantsPending(String query) => _pending.wantsPending(query);
}
