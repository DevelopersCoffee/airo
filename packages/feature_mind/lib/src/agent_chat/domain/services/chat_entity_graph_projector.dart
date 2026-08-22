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
            (_hasBuilder(facts) && facts.containsKey('Project'));
      default:
        return facts.isNotEmpty;
    }
  }

  static bool _hasBuilder(Map<String, String> facts) =>
      facts.containsKey('Builder') ||
      facts.containsKey('Builder Track Record Notes');

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
      ...graph.nodes.where(_isClaim).map((node) => _projectClaim(graph, node)),
      ...graph.nodes
          .where(_isHospitalStay)
          .map((node) => _projectHospital(graph, node)),
      ...graph.nodes
          .where(_isProperty)
          .map((node) => _projectProperty(graph, node)),
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

  ProjectedChatJourney _projectHospital(
    ChatEntityGraph graph,
    ChatGraphNode stay,
  ) {
    final facts = <String, String>{};
    _copyIfPresent(facts, 'Hospital', stay.attributes['hospital']);
    _copyIfPresent(facts, 'Surgery Date', stay.attributes['date']);
    _copyIfPresent(facts, 'Required Tests List', stay.attributes['tests']);
    _copyIfPresent(
      facts,
      'Insurance Authorization Reference',
      stay.attributes['auth_ref'],
    );

    for (final edge in graph.edgesFor(stay.id)) {
      if (edge.predicate != ChatEntityRelation.relatedTo) continue;
      final otherId = edge.fromId == stay.id ? edge.toId : edge.fromId;
      final other = graph.nodeById(otherId);
      if (other == null) continue;
      if (other.type == EntityType.organization ||
          other.name.toLowerCase().contains('hospital')) {
        facts.putIfAbsent('Hospital', () => other.name);
      } else if (other.type == EntityType.date) {
        facts.putIfAbsent('Surgery Date', () => other.name);
      } else if (other.type == EntityType.identifier &&
          other.attributes['kind'] == 'auth_ref') {
        facts.putIfAbsent(
          'Insurance Authorization Reference',
          () =>
              other.attributes['value'] ?? other.name.replaceFirst('Auth ', ''),
        );
      } else if (other.type == EntityType.term) {
        facts.putIfAbsent('Required Tests List', () => other.name);
      }
    }

    final hospital = facts['Hospital'];
    return ProjectedChatJourney(
      subjectNodeId: stay.id,
      templateId: 'medical_surgery_v1',
      title: hospital == null ? 'Hospital stay' : '$hospital surgery',
      facts: facts,
    );
  }

  ProjectedChatJourney _projectProperty(
    ChatEntityGraph graph,
    ChatGraphNode property,
  ) {
    final facts = <String, String>{};
    _copyIfPresent(
      facts,
      'RERA Registration Number',
      property.attributes['rera'],
    );
    _copyIfPresent(facts, 'Builder', property.attributes['builder']);
    _copyIfPresent(
      facts,
      'Builder Track Record Notes',
      property.attributes['builder'],
    );
    _copyIfPresent(facts, 'Project', property.attributes['project']);
    _copyIfPresent(facts, 'Your Target Floor', property.attributes['floor']);

    for (final edge in graph.edgesFor(property.id)) {
      if (edge.predicate != ChatEntityRelation.relatedTo) continue;
      final otherId = edge.fromId == property.id ? edge.toId : edge.fromId;
      final other = graph.nodeById(otherId);
      if (other == null) continue;
      if (other.type == EntityType.identifier &&
          other.attributes['kind'] == 'rera') {
        facts.putIfAbsent(
          'RERA Registration Number',
          () =>
              other.attributes['value'] ?? other.name.replaceFirst('RERA ', ''),
        );
      } else if (other.type == EntityType.organization ||
          other.attributes['role'] == 'builder') {
        facts.putIfAbsent('Builder', () => other.name);
        facts.putIfAbsent('Builder Track Record Notes', () => other.name);
      } else if (other.type == EntityType.term) {
        facts.putIfAbsent('Project', () => other.name);
      }
    }

    final titleParts = [
      if (facts['Builder'] != null) facts['Builder'],
      if (facts['Project'] != null) facts['Project'],
    ];
    return ProjectedChatJourney(
      subjectNodeId: property.id,
      templateId: 'real_estate_under_construction_v1',
      title: titleParts.isEmpty ? 'Property purchase' : titleParts.join(' '),
      facts: facts,
    );
  }

  void _copyIfPresent(Map<String, String> facts, String key, String? value) {
    if (value == null || value.isEmpty) return;
    facts[key] = value;
  }

  bool _isClaim(ChatGraphNode node) =>
      node.type == EntityType.identifier && node.attributes['kind'] == 'claim';

  bool _isHospitalStay(ChatGraphNode node) =>
      node.attributes['kind'] == 'hospital_stay';

  bool _isProperty(ChatGraphNode node) => node.attributes['kind'] == 'property';

  String _digits(String name) =>
      RegExp(r'[A-Z0-9]{5,20}').firstMatch(name)?.group(0) ?? name;
}
