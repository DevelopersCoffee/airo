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

  test('claim plus hospital yields insurance and surgery journeys', () {
    final graph = linker.ingest(
      ChatEntityGraph.empty,
      'Niva Bupa reimbursement Claim ID 9001001 after surgery at City Hospital '
      'on 12 Sep, pre-op tests CBC and ECG, auth ref PREAUTH-44',
    );

    final journeys = projector.project(graph);
    expect(
      journeys.map((journey) => journey.templateId),
      containsAll(['insurance_claim_v1', 'medical_surgery_v1']),
    );
    final surgery = journeys.singleWhere(
      (journey) => journey.templateId == 'medical_surgery_v1',
    );
    expect(surgery.facts['Required Tests List'], contains('CBC'));
    expect(surgery.facts['Insurance Authorization Reference'], 'PREAUTH-44');
    expect(surgery.isOfferable, isTrue);
  });

  test('property-only graph yields an under-construction journey', () {
    final graph = linker.ingest(
      ChatEntityGraph.empty,
      'buying Tower B floor 14 from Prestige, RERA P52100012345',
    );

    final journeys = projector.project(graph);
    expect(journeys, hasLength(1));
    expect(journeys.single.templateId, 'real_estate_under_construction_v1');
    expect(journeys.single.facts['RERA Registration Number'], 'P52100012345');
    expect(journeys.single.facts['Your Target Floor'], '14');
    expect(journeys.single.isOfferable, isTrue);
  });

  test(
    'firstUnoffered skips a marked hospital journey and keeps the claim',
    () {
      var graph = linker.ingest(
        ChatEntityGraph.empty,
        'Niva Bupa Claim ID 9001001 after surgery at City Hospital on 12 Sep',
      );
      final surgery = projector
          .project(graph)
          .singleWhere((journey) => journey.templateId == 'medical_surgery_v1');
      graph = graph.withNodeAttribute(
        surgery.subjectNodeId,
        'journey_offered',
        'true',
      );

      final next = projector.firstUnoffered(graph);
      expect(next, isNotNull);
      expect(next!.templateId, 'insurance_claim_v1');
    },
  );
}
