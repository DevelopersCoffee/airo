import 'package:feature_mind/src/agent_chat/domain/models/chat_entity_graph.dart';
import 'package:feature_mind/src/agent_chat/presentation/widgets/chat_entity_graph_panel.dart';
import 'package:feature_mind/src/provenance/domain/models/extracted_entity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('hides when the graph is empty', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ChatEntityGraphPanel(graph: ChatEntityGraph.empty),
        ),
      ),
    );

    expect(find.byKey(const Key('chat.entity_graph.panel')), findsNothing);
  });

  testWidgets('lists entities and relations', (tester) async {
    const graph = ChatEntityGraph(
      nodes: [
        ChatGraphNode(
          id: 'identifier:9001001',
          type: EntityType.identifier,
          name: 'Claim 9001001',
        ),
        ChatGraphNode(
          id: 'organization:niva-bupa',
          type: EntityType.organization,
          name: 'Niva Bupa',
        ),
      ],
      edges: [
        ChatGraphEdge(
          fromId: 'identifier:9001001',
          toId: 'organization:niva-bupa',
          predicate: ChatEntityRelation.insuredBy,
        ),
      ],
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ChatEntityGraphPanel(graph: graph)),
      ),
    );

    expect(find.byKey(const Key('chat.entity_graph.panel')), findsOneWidget);
    expect(find.textContaining('Claim 9001001'), findsWidgets);
    expect(find.textContaining('insured_by'), findsWidgets);
  });

  testWidgets('expanded panel does not overflow a short window', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 240);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const graph = ChatEntityGraph(
      nodes: [
        ChatGraphNode(
          id: 'term:claim',
          type: EntityType.identifier,
          name: 'Claim 9001001',
        ),
      ],
      edges: [],
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ChatEntityGraphPanel(graph: graph)),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('chat.entity_graph.panel')), findsOneWidget);
  });
}
