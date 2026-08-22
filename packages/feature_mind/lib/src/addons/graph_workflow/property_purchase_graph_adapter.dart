import 'package:core_ai/core_ai.dart';
import 'package:core_domain/core_domain.dart';

import '../../agent_chat/domain/models/chat_entity_graph.dart';
import '../../agent_chat/domain/models/entity_graph_bridge.dart';
import '../../agent_chat/domain/services/chat_entity_graph_pending.dart';
import '../../agent_chat/domain/services/projected_chat_journey.dart';
import '../../agent_chat/domain/services/life_track_fact_extractor.dart';
import 'legacy_chat_entity_linker.dart';
import 'legacy_workflow_graph_patch.dart';
import 'legacy_workflow_projection.dart';

/// Graph-workflow adapter for the Property Purchase built-in add-on.
class PropertyPurchaseGraphAdapter implements GraphWorkflowAddonAdapter {
  PropertyPurchaseGraphAdapter({
    LifeTrackFactExtractor facts = const LifeTrackFactExtractor(),
    LegacyChatEntityLinker linker = const LegacyChatEntityLinker(),
    ChatEntityGraphPending? pending,
  }) : _facts = facts,
       _linker = linker,
       _pending = pending ?? ChatEntityGraphPending();

  static const addonId = 'property-purchase-planner';
  static const templateId = 'real_estate_under_construction_v1';

  final LifeTrackFactExtractor _facts;
  final LegacyChatEntityLinker _linker;
  final ChatEntityGraphPending _pending;

  @override
  AddonIdentity get identity =>
      const AddonIdentity(id: AddonId(addonId), version: '1.0.0');

  @override
  bool accepts(GraphIngestContext input) {
    if (_pending.looksProperty(input.text)) return true;
    if (_facts.looksPropertyPurchase(input.text)) return true;
    return _facts.extractPropertyPurchase(input.text).facts.isNotEmpty;
  }

  @override
  Future<EntityGraphPatch> extract(GraphIngestContext input) async {
    if (!accepts(input)) return const EntityGraphPatch();
    final before = ChatEntityGraphBridge.fromEntityGraph(input.graph);
    final after = _linker.ingestPropertyDomain(before, input.text);
    return LegacyWorkflowGraphPatch.delta(before, after);
  }

  @override
  Iterable<WorkflowProjection> project(EntityGraph graph) {
    final chatGraph = ChatEntityGraphBridge.fromEntityGraph(graph);
    return chatGraph.nodes
        .where((node) => node.attributes['kind'] == 'property')
        .map((property) => _toProjection(
          LegacyWorkflowProjection.property(chatGraph, property),
          chatGraph,
        ));
  }

  @override
  PendingAssessment assessPending(
    EntityGraph graph,
    WorkflowProjection projection,
  ) {
    final chatGraph = ChatEntityGraphBridge.fromEntityGraph(graph);
    final node = graph.nodeById(projection.subjectNodeId);
    if (node == null) {
      return PendingAssessment(
        identity: identity,
        subjectNodeId: projection.subjectNodeId,
        storedFacts: projection.factsByFieldId,
        missingRequired: const [],
        missingOptional: const [],
      );
    }
    final chatNode = chatGraph.nodeById(node.id);
    if (chatNode == null) {
      return PendingAssessment(
        identity: identity,
        subjectNodeId: projection.subjectNodeId,
        storedFacts: projection.factsByFieldId,
        missingRequired: const [],
        missingOptional: const [],
      );
    }
    final journey = LegacyWorkflowProjection.property(chatGraph, chatNode);
    return PendingAssessment(
      identity: identity,
      subjectNodeId: projection.subjectNodeId,
      storedFacts: journey.facts,
      missingRequired: _pending.missingFieldsFor(journey),
      missingOptional: const [],
      crossLinks: _pending.crossLinksFor(chatGraph, journey.subjectNodeId),
    );
  }

  WorkflowProjection _toProjection(
    ProjectedChatJourney journey,
    ChatEntityGraph graph,
  ) {
    final node = graph.nodeById(journey.subjectNodeId);
    final offered = node?.attributes['journey_offered'] == 'true';
    return WorkflowProjection(
      identity: identity,
      subjectNodeId: journey.subjectNodeId,
      destinationKind: 'lifetrack',
      templateId: journey.templateId,
      templateVersion: '1',
      title: journey.title,
      factsByFieldId: journey.facts,
      identityKey: journey.subjectNodeId,
      offer: offered
          ? const OfferDecision(kind: OfferDecisionKind.alreadyOffered)
          : journey.isOfferable
          ? const OfferDecision(kind: OfferDecisionKind.offerable)
          : const OfferDecision(
              kind: OfferDecisionKind.notOfferable,
              reason: 'missing_required_facts',
            ),
    );
  }
}
