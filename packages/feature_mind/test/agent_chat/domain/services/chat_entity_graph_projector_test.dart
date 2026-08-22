import 'package:feature_mind/src/agent_chat/domain/models/chat_entity_graph.dart';
import 'package:feature_mind/src/agent_chat/domain/services/chat_entity_graph_projector.dart';
import 'package:feature_mind/src/agent_chat/domain/services/chat_entity_linker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const linker = ChatEntityLinker();
  const projector = ChatEntityGraphProjector();

  test('projects a claim graph into an insurance LifeTrack payload', () {
    final graph = linker.ingest(
      ChatEntityGraph.empty,
      'Niva Bupa reimbursement Claim ID 9001001 via Policybazaar. '
      'All documents received.',
    );

    final journeys = projector.project(graph);
    expect(journeys, hasLength(1));
    expect(journeys.single.templateId, 'insurance_claim_v1');
    expect(journeys.single.facts['Claim ID'], '9001001');
    expect(journeys.single.facts['Insurer'], 'Niva Bupa');
    expect(journeys.single.facts['Broker / Intermediary'], 'Policybazaar');
    expect(journeys.single.title, contains('9001001'));
    expect(projector.firstUnoffered(graph), isNotNull);
  });

  test('does not re-offer a journey already marked offered', () {
    var graph = linker.ingest(
      ChatEntityGraph.empty,
      'Niva Bupa Claim ID 9001001',
    );
    graph = graph.withNodeAttribute(
      'identifier:9001001',
      'journey_offered',
      'true',
    );

    expect(projector.firstUnoffered(graph), isNull);
  });

  test(
    'Niva Bupa claim plus City Hospital yields insurance and surgery journeys',
    () {
      final graph = linker.ingest(
        ChatEntityGraph.empty,
        'Niva Bupa Claim ID 9001001 after surgery at City Hospital.',
      );

      final journeys = projector.project(graph);
      expect(
        journeys.map((journey) => journey.templateId),
        containsAll(['insurance_claim_v1', 'medical_surgery_v1']),
      );
      expect(journeys, hasLength(2));
      final surgery = journeys.singleWhere(
        (journey) => journey.templateId == 'medical_surgery_v1',
      );
      expect(surgery.isOfferable, isTrue);
      expect(surgery.facts['Hospital'], 'City Hospital');
      final claim = journeys.singleWhere(
        (journey) => journey.templateId == 'insurance_claim_v1',
      );
      expect(claim.facts['Claim ID'], '9001001');
    },
  );

  test(
    'property-only graph yields a real_estate_under_construction journey',
    () {
      final graph = linker.ingest(
        ChatEntityGraph.empty,
        'buying Tower B floor 14 from Prestige, RERA P52100012345',
      );

      final journeys = projector.project(graph);
      expect(journeys, hasLength(1));
      expect(journeys.single.templateId, 'real_estate_under_construction_v1');
      expect(journeys.single.isOfferable, isTrue);
      expect(journeys.single.facts['RERA Registration Number'], 'P52100012345');
      expect(journeys.single.facts['Your Target Floor'], '14');
      expect(projector.firstUnoffered(graph), isNotNull);
    },
  );

  test('firstUnoffered skips a marked claim and still offers hospital', () {
    var graph = linker.ingest(
      ChatEntityGraph.empty,
      'Niva Bupa Claim ID 9001001 after surgery at City Hospital.',
    );
    graph = graph.withNodeAttribute(
      'identifier:9001001',
      'journey_offered',
      'true',
    );

    final next = projector.firstUnoffered(graph);
    expect(next, isNotNull);
    expect(next!.templateId, 'medical_surgery_v1');

    graph = graph.withNodeAttribute(
      next.subjectNodeId,
      'journey_offered',
      'true',
    );
    expect(projector.firstUnoffered(graph), isNull);
  });
}
