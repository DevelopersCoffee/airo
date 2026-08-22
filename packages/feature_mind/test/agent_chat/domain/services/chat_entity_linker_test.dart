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
      graph.nodes.where(
        (node) =>
            node.type == EntityType.identifier &&
            node.attributes['kind'] == 'claim',
      ),
      hasLength(1),
    );
  });

  test('surgery-only message creates a hospital journey subject', () {
    final graph = linker.ingest(
      ChatEntityGraph.empty,
      'surgery at City Hospital on 12 Sep, pre-op tests CBC and ECG, '
      'auth ref PREAUTH-44',
    );

    final surgery = graph.nodes.singleWhere(
      (node) =>
          node.type == EntityType.identifier &&
          node.attributes['kind'] == 'surgery',
    );
    expect(surgery.name.toLowerCase(), contains('city hospital'));
    expect(
      graph.nodes.map((node) => node.name),
      containsAll(['City Hospital', 'PREAUTH-44']),
    );
    expect(
      graph.edges.any(
        (edge) =>
            edge.fromId == surgery.id &&
            edge.toId.contains('city-hospital') &&
            edge.predicate == ChatEntityRelation.relatedTo,
      ),
      isTrue,
    );
    expect(
      graph.nodes.where(
        (node) =>
            node.type == EntityType.identifier &&
            node.attributes['kind'] == 'claim',
      ),
      isEmpty,
    );
  });

  test('property purchase extracts RERA and builder nodes', () {
    final graph = linker.ingest(
      ChatEntityGraph.empty,
      'buying Tower B floor 14 from Prestige, RERA P52100012345',
    );

    expect(
      graph.nodes.any(
        (node) =>
            node.type == EntityType.identifier &&
            node.attributes['kind'] == 'rera' &&
            (node.attributes['value'] == 'P52100012345' ||
                node.name.contains('P52100012345')),
      ),
      isTrue,
    );
    expect(
      graph.nodes.map((node) => node.name),
      containsAll(['Prestige', 'Tower B']),
    );
  });
}
