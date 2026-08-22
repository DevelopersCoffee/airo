import 'package:core_ai/core_ai.dart';
import 'package:core_domain/core_domain.dart';

import '../../agent_chat/domain/models/chat_entity_graph.dart';
import '../../agent_chat/domain/models/entity_graph_bridge.dart';
import '../../agent_chat/domain/services/chat_entity_graph_projector.dart';
import '../../agent_chat/domain/services/chat_entity_graph_pending.dart';
import '../../agent_chat/domain/services/life_track_fact_extractor.dart';
import 'graph_workflow_projection_bridge.dart';

/// Graph-workflow adapter for the Insurance Planner built-in add-on.
class InsurancePlannerGraphAdapter implements GraphWorkflowAddonAdapter {
  InsurancePlannerGraphAdapter({
    LifeTrackFactExtractor facts = const LifeTrackFactExtractor(),
    GraphWorkflowProjectionBridge projectionBridge =
        const GraphWorkflowProjectionBridge(),
    ChatEntityGraphPending pending = const ChatEntityGraphPending(),
  }) : _facts = facts,
       _projectionBridge = projectionBridge,
       _pending = pending;

  static const addonId = 'insurance-planner';
  static const templateId = 'insurance_claim_v1';

  final LifeTrackFactExtractor _facts;
  final GraphWorkflowProjectionBridge _projectionBridge;
  final ChatEntityGraphPending _pending;

  @override
  AddonIdentity get identity =>
      const AddonIdentity(id: AddonId(addonId), version: '1.0.0');

  @override
  bool accepts(GraphIngestContext input) {
    if (_pending.looksInsurance(input.text)) return true;
    final extracted = _facts.extractInsuranceClaim(input.text);
    return extracted.facts.isNotEmpty;
  }

  @override
  Future<EntityGraphPatch> extract(GraphIngestContext input) async {
    return const EntityGraphPatch();
  }

  @override
  Iterable<WorkflowProjection> project(EntityGraph graph) {
    final chatGraph = ChatEntityGraphBridge.fromEntityGraph(graph);
    return _projectionBridge
        .projectChatJourneys(chatGraph)
        .where((journey) => journey.templateId == templateId)
        .map(
          (journey) => _projectionBridge.toWorkflowProjection(
            journey: journey,
            identity: identity,
            graph: chatGraph,
          ),
        );
  }

  @override
  PendingAssessment assessPending(
    EntityGraph graph,
    WorkflowProjection projection,
  ) {
    final chatGraph = ChatEntityGraphBridge.fromEntityGraph(graph);
    ProjectedChatJourney? journey;
    for (final item in _projectionBridge.projectChatJourneys(chatGraph)) {
      if (item.subjectNodeId == projection.subjectNodeId) {
        journey = item;
        break;
      }
    }
    if (journey == null) {
      return PendingAssessment(
        identity: identity,
        subjectNodeId: projection.subjectNodeId,
        storedFacts: projection.factsByFieldId,
        missingRequired: const [],
        missingOptional: const [],
      );
    }
    return PendingAssessment(
      identity: identity,
      subjectNodeId: projection.subjectNodeId,
      storedFacts: journey.facts,
      missingRequired: _pending.missingFieldsFor(journey),
      missingOptional: const [],
      crossLinks: _pending.crossLinksFor(chatGraph, journey.subjectNodeId),
    );
  }
}
