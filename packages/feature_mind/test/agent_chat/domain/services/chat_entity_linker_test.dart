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
      graph.edges,
      contains(
        const ChatGraphEdge(
          fromId: 'identifier:9001001',
          toId: 'term:city-hospital',
          predicate: ChatEntityRelation.relatedTo,
        ),
      ),
    );
    expect(
      graph.nodeById('organization:niva-bupa')?.type,
      EntityType.organization,
    );
  });
}
