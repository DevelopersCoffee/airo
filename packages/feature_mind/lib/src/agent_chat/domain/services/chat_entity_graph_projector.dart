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

  bool get isOfferable {
    switch (templateId) {
      case 'insurance_claim_v1':
        return facts.containsKey('Claim ID') ||
            facts.containsKey('Policy Number');
      case 'medical_surgery_v1':
        return facts.containsKey('Hospital') ||
            facts.containsKey('Surgery Date');
      case 'real_estate_under_construction_v1':
        return facts.containsKey('RERA Registration Number') ||
            (facts.containsKey('Builder Track Record Notes') &&
                facts.containsKey('Project'));
      default:
        return false;
    }
  }

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
    return [
      for (final claim in graph.nodes.where(_isClaim))
        _projectClaim(graph, claim),
      for (final surgery in graph.nodes.where(_isSurgery))
        _projectSurgery(graph, surgery),
      for (final property in graph.nodes.where(_isProperty))
        _projectProperty(graph, property),
    ];
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

  ProjectedChatJourney _projectSurgery(
    ChatEntityGraph graph,
    ChatGraphNode surgery,
  ) {
    final facts = <String, String>{};
    final date = surgery.attributes['date'];
    if (date != null && date.isNotEmpty) facts['Surgery Date'] = date;

    final tests = <String>[];
    for (final edge in graph.edgesFor(surgery.id)) {
      if (edge.predicate != ChatEntityRelation.relatedTo) continue;
      final otherId = edge.fromId == surgery.id ? edge.toId : edge.fromId;
      final other = graph.nodeById(otherId);
      if (other == null) continue;
      if (other.type == EntityType.organization) {
        facts['Hospital'] = other.name;
      } else if (other.type == EntityType.identifier &&
          other.attributes['kind'] == 'auth_ref') {
        facts['Insurance Authorization Reference'] =
            other.attributes['value'] ?? other.name.replaceFirst('Auth ', '');
      } else if (other.type == EntityType.term) {
        tests.add(other.name);
      } else if (other.type == EntityType.date) {
        facts.putIfAbsent('Surgery Date', () => other.name);
      }
    }
    if (tests.isNotEmpty) {
      facts['Required Tests List'] = tests.join(', ');
    }

    final hospital = facts['Hospital'];
    return ProjectedChatJourney(
      subjectNodeId: surgery.id,
      templateId: 'medical_surgery_v1',
      title: hospital == null ? 'Hospital stay' : 'Surgery at $hospital',
      facts: facts,
    );
  }

  ProjectedChatJourney _projectProperty(
    ChatEntityGraph graph,
    ChatGraphNode property,
  ) {
    final facts = <String, String>{};
    final floor = property.attributes['floor'];
    if (floor != null && floor.isNotEmpty) {
      facts['Your Target Floor'] = floor;
    }

    for (final edge in graph.edgesFor(property.id)) {
      if (edge.predicate != ChatEntityRelation.relatedTo) continue;
      final otherId = edge.fromId == property.id ? edge.toId : edge.fromId;
      final other = graph.nodeById(otherId);
      if (other == null) continue;
      if (other.type == EntityType.identifier &&
          other.attributes['kind'] == 'rera') {
        facts['RERA Registration Number'] =
            other.attributes['value'] ?? other.name.replaceFirst('RERA ', '');
      } else if (other.type == EntityType.organization) {
        facts['Builder Track Record Notes'] = other.name;
      } else if (other.type == EntityType.term) {
        facts['Project'] = other.name;
      }
    }

    return ProjectedChatJourney(
      subjectNodeId: property.id,
      templateId: 'real_estate_under_construction_v1',
      title: property.name,
      facts: facts,
    );
  }

  bool _isClaim(ChatGraphNode node) =>
      node.type == EntityType.identifier && node.attributes['kind'] == 'claim';

  bool _isSurgery(ChatGraphNode node) =>
      node.type == EntityType.identifier &&
      node.attributes['kind'] == 'surgery';

  bool _isProperty(ChatGraphNode node) =>
      node.type == EntityType.identifier &&
      node.attributes['kind'] == 'property';

  String _digits(String name) =>
      RegExp(r'[A-Z0-9]{5,20}').firstMatch(name)?.group(0) ?? name;
}
