import 'package:core_ai/core_ai.dart';
import 'package:core_domain/core_domain.dart';

import '../../agent_chat/domain/models/chat_entity_graph.dart';
import '../../agent_chat/domain/models/entity_graph_bridge.dart';
import '../../agent_chat/domain/services/chat_entity_graph_pending.dart';
import '../../agent_chat/domain/services/chat_entity_graph_projector.dart';
import '../../agent_chat/domain/services/chat_entity_linker.dart';
import 'graph_workflow_projection_bridge.dart';

/// Routes graph-workflow add-ons through the registry without host ID switches.
class GraphWorkflowCoordinator {
  GraphWorkflowCoordinator(
    this._registry, {
    ChatEntityLinker linker = const ChatEntityLinker(),
    GraphWorkflowProjectionBridge projectionBridge =
        const GraphWorkflowProjectionBridge(),
    ChatEntityGraphPending pending = const ChatEntityGraphPending(),
  }) : _linker = linker,
       _projectionBridge = projectionBridge,
       _pending = pending;

  final AddonRegistry _registry;
  final ChatEntityLinker _linker;
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
    return _linker.ingest(graph, text);
  }

  List<ProjectedChatJourney> projectJourneys(ChatEntityGraph graph) =>
      _projectionBridge.projectChatJourneys(graph);

  ProjectedChatJourney? firstUnofferedJourney(ChatEntityGraph graph) =>
      _projectionBridge.firstUnoffered(graph);

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
