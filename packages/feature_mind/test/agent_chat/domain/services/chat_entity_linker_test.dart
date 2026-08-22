import 'package:feature_mind/src/agent_chat/domain/models/chat_entity_graph.dart';
import 'package:feature_mind/src/agent_chat/domain/services/chat_entity_linker.dart';
import 'package:feature_mind/src/provenance/domain/models/extracted_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const linker = ChatEntityLinker();

  test(
    'extracts claim, insurer, broker and typed relations from one message',
    () {
      final graph = linker.ingest(
        ChatEntityGraph.empty,
        'Niva Bupa reimbursement Claim ID 9001001 via Policybazaar. '
        'All documents received.',
      );

      expect(
        graph.nodes.map((node) => node.name),
        containsAll(['Niva Bupa', 'Policybazaar', 'Claim 9001001']),
      );
      expect(
        graph.edges,
        containsAll([
          ChatGraphEdge(
            fromId: 'identifier:9001001',
            toId: 'organization:niva-bupa',
            predicate: ChatEntityRelation.insuredBy,
          ),
          ChatGraphEdge(
            fromId: 'identifier:9001001',
            toId: 'organization:policybazaar',
            predicate: ChatEntityRelation.filedVia,
          ),
          ChatGraphEdge(
            fromId: 'identifier:9001001',
            toId: 'document:claim-documents',
            predicate: ChatEntityRelation.hasDocument,
          ),
        ]),
      );
    },
  );

  test(
    'later chat about the same claim links follow-up onto the stored id',
    () {
      var graph = linker.ingest(
        ChatEntityGraph.empty,
        'Track this claim: Niva Bupa Claim ID 9001001',
      );
      graph = linker.ingest(
        graph,
        'Missed call from the claims team on that claim.',
      );

      final claim = graph.nodeById('identifier:9001001');
      expect(claim, isNotNull);
      expect(claim!.attributes['follow_up'], contains('Missed call'));
    },
  );

  test('a hospital mention can relate to the claim without replacing it', () {
    var graph = linker.ingest(
      ChatEntityGraph.empty,
      'Claim ID 9001001 with Niva Bupa after surgery at City Hospital.',
    );

    expect(
      graph.edges.any(
        (edge) =>
            edge.fromId == 'identifier:9001001' &&
            edge.toId.contains('city-hospital') &&
            edge.predicate == ChatEntityRelation.relatedTo,
      ),
      isTrue,
    );
    expect(
      graph.nodeById('organization:niva-bupa')?.type,
      EntityType.organization,
    );
    expect(
      graph.nodes.any((node) => node.attributes['kind'] == 'claim'),
      isTrue,
    );
  });

  test('surgery-only message creates a hospital journey subject', () {
    final graph = linker.ingest(
      ChatEntityGraph.empty,
      'surgery at City Hospital on 12 Sep, pre-op tests CBC and ECG, '
      'auth ref PREAUTH-44',
    );

    expect(
      graph.nodes.any((node) => node.attributes['kind'] == 'hospital_stay'),
      isTrue,
    );
    expect(
      graph.nodes.any((node) => node.attributes['kind'] == 'claim'),
      isFalse,
    );
    expect(graph.nodes.map((node) => node.name), contains('City Hospital'));
    expect(
      graph.nodes.any(
        (node) =>
            node.attributes['kind'] == 'auth_ref' &&
            (node.attributes['value'] == 'PREAUTH-44' ||
                node.name.contains('PREAUTH-44')),
      ),
      isTrue,
    );
    final stay = graph.nodes.firstWhere(
      (node) => node.attributes['kind'] == 'hospital_stay',
    );
    expect(
      graph.edges.any(
        (edge) =>
            (edge.fromId == stay.id && edge.toId.contains('city-hospital') ||
                edge.toId == stay.id &&
                    edge.fromId.contains('city-hospital')) &&
            edge.predicate == ChatEntityRelation.relatedTo,
      ),
      isTrue,
    );
  });

  test('City Hospital can link to a claim and a surgery node at once', () {
    final graph = linker.ingest(
      ChatEntityGraph.empty,
      'Claim ID 9001001 with Niva Bupa after surgery at City Hospital. '
      'pre-op tests CBC and ECG, auth ref PREAUTH-44',
    );

    final hospitalId = graph.nodes
        .firstWhere((node) => node.name == 'City Hospital')
        .id;
    final claimLinked = graph.edges.any(
      (edge) =>
          edge.predicate == ChatEntityRelation.relatedTo &&
          ((edge.fromId == 'identifier:9001001' && edge.toId == hospitalId) ||
              (edge.toId == 'identifier:9001001' && edge.fromId == hospitalId)),
    );
    final stay = graph.nodes.firstWhere(
      (node) => node.attributes['kind'] == 'hospital_stay',
    );
    final stayLinked = graph.edges.any(
      (edge) =>
          edge.predicate == ChatEntityRelation.relatedTo &&
          ((edge.fromId == stay.id && edge.toId == hospitalId) ||
              (edge.toId == stay.id && edge.fromId == hospitalId)),
    );
    expect(claimLinked, isTrue);
    expect(stayLinked, isTrue);
    expect(graph.nodeById('identifier:9001001'), isNotNull);
  });

  test('property RERA and builder nodes become a purchase subject', () {
    final graph = linker.ingest(
      ChatEntityGraph.empty,
      'buying Tower B floor 14 from Prestige, RERA P52100012345',
    );

    expect(
      graph.nodes.any((node) => node.attributes['kind'] == 'property'),
      isTrue,
    );
    expect(
      graph.nodes.any(
        (node) =>
            node.attributes['kind'] == 'rera' &&
            (node.attributes['value'] == 'P52100012345' ||
                node.name.contains('P52100012345')),
      ),
      isTrue,
    );
    expect(graph.nodes.map((node) => node.name), contains('Prestige'));
    final builder = graph.nodes.firstWhere((node) => node.name == 'Prestige');
    expect(builder.type, EntityType.organization);
    expect(builder.attributes['role'], 'builder');
  });
}
