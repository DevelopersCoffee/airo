import 'package:core_domain/core_domain.dart';

import '../../../provenance/domain/models/extracted_entity.dart';
import '../models/chat_entity_graph.dart';

/// One LifeTrack-shaped journey projected from the chat entity graph.
class ProjectedChatJourney {
  const ProjectedChatJourney({
    required this.subjectNodeId,
    required this.templateId,
    required this.title,
    required this.facts,
  });

  final String subjectNodeId;
  final String templateId;
  final String title;
  final Map<String, String> facts;

  bool get isOfferable =>
      facts.containsKey('Claim ID') || facts.containsKey('Policy Number');

  Map<String, dynamic> toPendingWrite() => {
    'title': title,
    'template_id': templateId,
    'facts': facts,
    'confirmed': true,
    'source': 'user_confirm',
  };
}

/// conversation → entities → workflow: turns stored graph nodes into a
/// template payload. Does not invent facts that are not on the graph.
class ChatEntityGraphProjector {
  const ChatEntityGraphProjector();

  List<ProjectedChatJourney> project(ChatEntityGraph graph) {
    final claims = graph.nodes.where(_isClaim).toList(growable: false);
    if (claims.isNotEmpty) {
      return claims
          .map((claim) => _projectClaim(graph, claim))
          .toList(growable: false);
    }
    return const [];
  }

  ProjectedChatJourney? firstUnoffered(ChatEntityGraph graph) {
    for (final journey in project(graph)) {
      final node = graph.nodeById(journey.subjectNodeId);
      if (node?.attributes['journey_offered'] == 'true') continue;
      if (!journey.isOfferable) continue;
      return journey;
    }
    return null;
  }

  ProjectedChatJourney _projectClaim(
    ChatEntityGraph graph,
    ChatGraphNode claim,
  ) {
    final facts = <String, String>{};
    final claimId = claim.attributes['value'] ?? _digits(claim.name);
    if (claimId.isNotEmpty) facts['Claim ID'] = claimId;
    facts['Claim Submission Reference'] = claimId;
    final followUp = claim.attributes['follow_up'];
    if (followUp != null && followUp.isNotEmpty) {
      facts['Follow-up Log'] = followUp;
    }

    String? insurer;
    for (final edge in graph.edgesFor(claim.id)) {
      final otherId = edge.fromId == claim.id ? edge.toId : edge.fromId;
      final other = graph.nodeById(otherId);
      if (other == null) continue;
      switch (edge.predicate) {
        case ChatEntityRelation.insuredBy:
          insurer = other.name;
          facts['Insurer'] = other.name;
        case ChatEntityRelation.filedVia:
          facts['Broker / Intermediary'] = other.name;
        case ChatEntityRelation.hasDocument:
          facts[LifeTrackFactPatch.documentsReceivedKey] =
              other.attributes['status'] ?? 'received';
          facts['Evidence Notes'] = 'Documents received for this claim.';
        case ChatEntityRelation.relatedTo:
          if (other.type == EntityType.identifier &&
              other.attributes['kind'] == 'policy') {
            facts['Policy Number'] =
                other.attributes['value'] ??
                other.name.replaceFirst('Policy ', '');
          } else if (other.type == EntityType.identifier &&
              other.attributes['kind'] == 'broker_ref') {
            facts['Intermediary Reference'] =
                other.attributes['value'] ??
                other.name.replaceFirst('Ref ', '');
          } else if (other.type == EntityType.term) {
            facts['Product Name'] = other.name;
          }
      }
    }

    final title = [
      insurer ?? 'Insurance',
      'claim',
      if (claimId.isNotEmpty) claimId,
    ].join(' ');
    return ProjectedChatJourney(
      subjectNodeId: claim.id,
      templateId: 'insurance_claim_v1',
      title: title,
      facts: facts,
    );
  }

  bool _isClaim(ChatGraphNode node) =>
      node.type == EntityType.identifier && node.attributes['kind'] == 'claim';

  String _digits(String name) =>
      RegExp(r'[A-Z0-9]{5,20}').firstMatch(name)?.group(0) ?? name;
}
