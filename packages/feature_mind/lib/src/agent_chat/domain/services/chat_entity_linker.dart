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
    ChatGraphNode? claim;
    ChatGraphNode? insurer;
    ChatGraphNode? broker;
    ChatGraphNode? policy;
    ChatGraphNode? documents;

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

    for (final entity in extractor.extract(text)) {
      if (_coveredByFacts(entity, extractedFacts.facts)) continue;
      final node = ChatGraphNode(
        id: _id(entity.type, entity.text),
        type: entity.type,
        name: entity.text,
      );
      addNode(node);
      if (claim != null &&
          (entity.type == EntityType.person ||
              entity.type == EntityType.date ||
              _looksMedical(entity.text))) {
        link(claim.id, ChatEntityRelation.relatedTo, node.id);
      }
    }

    final uniqueNodes = {for (final node in nodes) node.id: node};
    if (uniqueNodes.length >= 2 && claim == null) {
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
