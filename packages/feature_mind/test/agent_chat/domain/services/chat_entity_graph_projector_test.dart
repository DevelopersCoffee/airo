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
}
