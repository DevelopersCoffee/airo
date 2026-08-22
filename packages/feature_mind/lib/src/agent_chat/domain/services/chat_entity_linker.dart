import 'package:core_domain/core_domain.dart';

import '../../../provenance/domain/models/extracted_entity.dart';
import '../../../provenance/domain/services/entity_extractor.dart';
import '../models/chat_entity_graph.dart';
import 'life_track_fact_extractor.dart';

/// Turns one chat turn into nodes and typed relations, then merges them
/// into the existing graph. On-device only; does not read email.
class ChatEntityLinker {
  const ChatEntityLinker({
    this.extractor = const RuleBasedEntityExtractor(),
    this.facts = const LifeTrackFactExtractor(),
  });

  final EntityExtractor extractor;
  final LifeTrackFactExtractor facts;

  ChatEntityGraph ingest(ChatEntityGraph graph, String text) {
    if (text.trim().isEmpty) return graph;

    final nodes = <ChatGraphNode>[];
    final edges = <ChatGraphEdge>[];
    final mentioned = <String>[];

    void addNode(ChatGraphNode node) {
      nodes.add(node);
      mentioned.add(node.id);
    }

    void link(String fromId, String predicate, String toId) {
      if (fromId == toId) return;
      edges.add(
        ChatGraphEdge(fromId: fromId, toId: toId, predicate: predicate),
      );
    }

    final extractedFacts = facts.extractInsuranceClaim(text);
    final medicalFacts = facts.extractMedicalSurgery(text);
    final propertyFacts = facts.extractPropertyPurchase(text);
    ChatGraphNode? claim;
    ChatGraphNode? insurer;
    ChatGraphNode? broker;
    ChatGraphNode? policy;
    ChatGraphNode? documents;
    ChatGraphNode? stay;
    ChatGraphNode? hospitalOrg;
    ChatGraphNode? property;

    final claimId = extractedFacts.facts['Claim ID'];
    if (claimId != null) {
      claim = _identifier('Claim $claimId', claimId, kind: 'claim');
      addNode(claim);
    }
    final ref = extractedFacts.facts['Intermediary Reference'];
    if (ref != null) {
      addNode(_identifier('Ref $ref', ref, kind: 'broker_ref'));
      if (claim != null) {
        link(
          claim.id,
          ChatEntityRelation.relatedTo,
          _id(EntityType.identifier, ref),
        );
      }
    }
    final insurerName = extractedFacts.facts['Insurer'];
    if (insurerName != null) {
      insurer = _organization(insurerName, role: 'insurer');
      addNode(insurer);
    }
    final brokerName = extractedFacts.facts['Broker / Intermediary'];
    if (brokerName != null) {
      broker = _organization(brokerName, role: 'broker');
      addNode(broker);
    }
    final policyNumber = extractedFacts.facts['Policy Number'];
    if (policyNumber != null) {
      policy = _identifier(
        'Policy $policyNumber',
        policyNumber,
        kind: 'policy',
      );
      addNode(policy);
    }
    final product = extractedFacts.facts['Product Name'];
    if (product != null) {
      addNode(_term(product));
    }
    if (extractedFacts.facts.containsKey(
          LifeTrackFactPatch.documentsReceivedKey,
        ) ||
        text.toLowerCase().contains('documents received')) {
      documents = const ChatGraphNode(
        id: 'document:claim-documents',
        type: EntityType.document,
        name: 'Claim documents',
        attributes: {'status': 'received'},
      );
      addNode(documents);
    }
    final followUp = extractedFacts.facts['Follow-up Log'];

    claim ??= _recentClaim(graph, text);
    if (followUp != null && claim != null) {
      claim = claim.merge(
        ChatGraphNode(
          id: claim.id,
          type: claim.type,
          name: claim.name,
          attributes: {'follow_up': followUp},
        ),
      );
      addNode(claim);
    }
    if (claim != null && insurer != null) {
      link(claim.id, ChatEntityRelation.insuredBy, insurer.id);
    }
    if (claim != null && broker != null) {
      link(claim.id, ChatEntityRelation.filedVia, broker.id);
    }
    if (claim != null && documents != null) {
      link(claim.id, ChatEntityRelation.hasDocument, documents.id);
    }
    if (claim != null && policy != null) {
      link(claim.id, ChatEntityRelation.relatedTo, policy.id);
    }

    final hospitalName = medicalFacts.facts['Hospital'];
    if (hospitalName != null) {
      hospitalOrg = _organization(hospitalName, role: 'hospital');
      addNode(hospitalOrg);
    }
    if (_hasHospitalAnchor(medicalFacts.facts)) {
      stay = _hospitalStay(
        hospitalName: hospitalName,
        facts: medicalFacts.facts,
      );
      addNode(stay);
    } else {
      stay = _recentSubject(
        graph,
        kind: 'hospital_stay',
        referBack: facts.looksHospitalStay(text),
      );
    }
    if (stay != null && hospitalOrg != null) {
      link(stay.id, ChatEntityRelation.relatedTo, hospitalOrg.id);
    }
    if (claim != null && hospitalOrg != null) {
      link(claim.id, ChatEntityRelation.relatedTo, hospitalOrg.id);
    }
    final auth = medicalFacts.facts['Insurance Authorization Reference'];
    if (auth != null) {
      final authNode = _identifier('Auth $auth', auth, kind: 'auth_ref');
      addNode(authNode);
      if (stay != null) {
        link(stay.id, ChatEntityRelation.relatedTo, authNode.id);
      }
    }
    final tests = medicalFacts.facts['Required Tests List'];
    if (tests != null) {
      final testsNode = _term(tests);
      addNode(testsNode);
      if (stay != null) {
        link(stay.id, ChatEntityRelation.relatedTo, testsNode.id);
      }
    }
    final surgeryDate = medicalFacts.facts['Surgery Date'];
    if (surgeryDate != null) {
      final dateNode = ChatGraphNode(
        id: _id(EntityType.date, surgeryDate),
        type: EntityType.date,
        name: surgeryDate,
      );
      addNode(dateNode);
      if (stay != null) {
        link(stay.id, ChatEntityRelation.relatedTo, dateNode.id);
      }
    }

    if (_hasPropertyAnchor(propertyFacts.facts)) {
      property = _propertySubject(propertyFacts.facts);
      addNode(property);
    } else {
      property = _recentSubject(
        graph,
        kind: 'property',
        referBack: facts.looksPropertyPurchase(text),
      );
    }
    final rera = propertyFacts.facts['RERA Registration Number'];
    if (rera != null) {
      final reraNode = _identifier('RERA $rera', rera, kind: 'rera');
      addNode(reraNode);
      if (property != null) {
        link(property.id, ChatEntityRelation.relatedTo, reraNode.id);
      }
    }
    final builderName = propertyFacts.facts['Builder'];
    if (builderName != null) {
      final builder = _organization(builderName, role: 'builder');
      addNode(builder);
      if (property != null) {
        link(property.id, ChatEntityRelation.relatedTo, builder.id);
      }
    }
    final projectName = propertyFacts.facts['Project'];
    if (projectName != null) {
      final projectNode = _term(projectName);
      addNode(projectNode);
      if (property != null) {
        link(property.id, ChatEntityRelation.relatedTo, projectNode.id);
      }
    }

    final combinedFacts = {
      ...extractedFacts.facts,
      ...medicalFacts.facts,
      ...propertyFacts.facts,
    };

    for (final entity in extractor.extract(text)) {
      if (_coveredByFacts(entity, combinedFacts)) continue;
      var node = ChatGraphNode(
        id: _id(entity.type, entity.text),
        type: entity.type,
        name: entity.text,
      );
      if (entity.type == EntityType.organization &&
          _looksMedical(entity.text)) {
        node = _organization(entity.text, role: 'hospital');
        hospitalOrg ??= node;
      }
      addNode(node);
      if (claim != null &&
          (entity.type == EntityType.person ||
              entity.type == EntityType.date ||
              _looksMedical(entity.text))) {
        link(claim.id, ChatEntityRelation.relatedTo, node.id);
      }
      if (stay != null &&
          (entity.type == EntityType.person ||
              entity.type == EntityType.date ||
              _looksMedical(entity.text))) {
        link(stay.id, ChatEntityRelation.relatedTo, node.id);
      }
    }

    if (stay == null && hospitalOrg != null && facts.looksHospitalStay(text)) {
      stay = _hospitalStay(
        hospitalName: hospitalOrg.name,
        facts: medicalFacts.facts,
      );
      addNode(stay);
      link(stay.id, ChatEntityRelation.relatedTo, hospitalOrg.id);
      if (claim != null) {
        link(claim.id, ChatEntityRelation.relatedTo, hospitalOrg.id);
      }
    }

    final uniqueNodes = <String, ChatGraphNode>{};
    for (final node in nodes) {
      final existing = uniqueNodes[node.id];
      uniqueNodes[node.id] = existing == null ? node : existing.merge(node);
    }
    if (uniqueNodes.length >= 2 &&
        claim == null &&
        stay == null &&
        property == null) {
      final ids = uniqueNodes.keys.toList(growable: false);
      for (var i = 0; i < ids.length; i++) {
        for (var j = i + 1; j < ids.length; j++) {
          link(ids[i], ChatEntityRelation.mentionedWith, ids[j]);
        }
      }
    }

    return graph.upsert(
      incomingNodes: uniqueNodes.values.toList(growable: false),
      incomingEdges: edges.toSet().toList(growable: false),
      mentionedIds: mentioned,
    );
  }

  bool _hasHospitalAnchor(Map<String, String> medical) =>
      medical.containsKey('Hospital') ||
      medical.containsKey('Surgery Date') ||
      medical.containsKey('Required Tests List') ||
      medical.containsKey('Insurance Authorization Reference');

  bool _hasPropertyAnchor(Map<String, String> property) =>
      property.containsKey('RERA Registration Number') ||
      property.containsKey('Builder') ||
      property.containsKey('Project') ||
      property.containsKey('Your Target Floor');

  ChatGraphNode _hospitalStay({
    required String? hospitalName,
    required Map<String, String> facts,
  }) {
    final key = hospitalName ?? facts['Surgery Date'] ?? 'hospital-stay';
    return ChatGraphNode(
      id: _id(EntityType.identifier, 'hospital-stay-$key'),
      type: EntityType.identifier,
      name: hospitalName == null ? 'Hospital stay' : '$hospitalName surgery',
      attributes: {
        'kind': 'hospital_stay',
        'hospital': ?hospitalName,
        'date': ?facts['Surgery Date'],
        'tests': ?facts['Required Tests List'],
        'auth_ref': ?facts['Insurance Authorization Reference'],
      },
    );
  }

  ChatGraphNode _propertySubject(Map<String, String> facts) {
    final key =
        facts['RERA Registration Number'] ??
        facts['Project'] ??
        facts['Builder'] ??
        'property';
    final titleParts = [?facts['Builder'], ?facts['Project']];
    return ChatGraphNode(
      id: _id(EntityType.identifier, 'property-$key'),
      type: EntityType.identifier,
      name: titleParts.isEmpty ? 'Property purchase' : titleParts.join(' '),
      attributes: {
        'kind': 'property',
        'rera': ?facts['RERA Registration Number'],
        'builder': ?facts['Builder'],
        'project': ?facts['Project'],
        'floor': ?facts['Your Target Floor'],
      },
    );
  }

  ChatGraphNode? _recentClaim(ChatEntityGraph graph, String text) {
    final lower = text.toLowerCase();
    final refersBack =
        lower.contains('claim') ||
        lower.contains('insurer') ||
        lower.contains('document') ||
        lower.contains('that') ||
        lower.contains('this');
    if (!refersBack) return null;
    for (final id in graph.recentNodeIds) {
      final node = graph.nodeById(id);
      if (node != null &&
          node.type == EntityType.identifier &&
          (node.attributes['kind'] == 'claim' ||
              id.startsWith('identifier:'))) {
        return node;
      }
    }
    return null;
  }

  ChatGraphNode? _recentSubject(
    ChatEntityGraph graph, {
    required String kind,
    required bool referBack,
  }) {
    if (!referBack) return null;
    for (final id in graph.recentNodeIds) {
      final node = graph.nodeById(id);
      if (node != null && node.attributes['kind'] == kind) return node;
    }
    return null;
  }

  bool _coveredByFacts(ExtractedEntity entity, Map<String, String> facts) {
    final haystack = facts.values.map(_slug).toSet();
    return haystack.contains(_slug(entity.text));
  }

  bool _looksMedical(String text) {
    final lower = text.toLowerCase();
    return lower.contains('hospital') ||
        lower.contains('surgery') ||
        lower.contains('discharge') ||
        lower.contains('ibuprofen');
  }

  ChatGraphNode _organization(String name, {required String role}) =>
      ChatGraphNode(
        id: _id(EntityType.organization, name),
        type: EntityType.organization,
        name: name,
        attributes: {'role': role},
      );

  ChatGraphNode _identifier(
    String name,
    String value, {
    required String kind,
  }) => ChatGraphNode(
    id: _id(EntityType.identifier, value),
    type: EntityType.identifier,
    name: name,
    attributes: {'kind': kind, 'value': value},
  );

  ChatGraphNode _term(String name) => ChatGraphNode(
    id: _id(EntityType.term, name),
    type: EntityType.term,
    name: name,
  );

  static String _id(EntityType type, String name) =>
      '${type.name}:${_slug(name)}';

  static String _slug(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
}
