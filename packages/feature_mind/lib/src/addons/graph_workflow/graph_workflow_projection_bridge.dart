import 'package:core_domain/core_domain.dart';

import '../../agent_chat/domain/models/chat_entity_graph.dart';
import '../../agent_chat/domain/services/chat_entity_graph_projector.dart';

/// Maps chat-local journeys to neutral workflow projections.
class GraphWorkflowProjectionBridge {
  const GraphWorkflowProjectionBridge();

  static const _projector = ChatEntityGraphProjector();

  List<ProjectedChatJourney> projectChatJourneys(ChatEntityGraph graph) =>
      _projector.project(graph);

  WorkflowProjection toWorkflowProjection({
    required ProjectedChatJourney journey,
    required AddonIdentity identity,
    required ChatEntityGraph graph,
  }) {
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

  ProjectedChatJourney? firstUnoffered(ChatEntityGraph graph) =>
      _projector.firstUnoffered(graph);
}
