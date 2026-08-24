import 'package:feature_mind/src/addons/built_in_addon_registry.dart';
import 'package:feature_mind/src/addons/graph_workflow/car_purchase_graph_adapter.dart';
import 'package:feature_mind/src/addons/graph_workflow/insurance_planner_graph_adapter.dart';
import 'package:feature_mind/src/addons/graph_workflow/graph_workflow_coordinator.dart';
import 'package:feature_mind/src/agent_chat/domain/models/chat_entity_graph.dart';
import 'package:feature_mind/src/agent_chat/domain/services/chat_entity_linker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('built-in registry routes insurance graph projections', () {
    final builtIn = BuiltInAddonRegistry.create();
    const linker = ChatEntityLinker();
    final graph = linker.ingest(
      ChatEntityGraph.empty,
      'Niva Bupa reimbursement Claim ID 9001001 via Policybazaar. '
      'All documents received.',
    );

    final projections = builtIn.graphCoordinator.workflowProjections(graph);
    expect(projections, isNotEmpty);
    expect(
      projections.any(
        (item) =>
            item.identity.id.value == InsurancePlannerGraphAdapter.addonId &&
            item.templateId == InsurancePlannerGraphAdapter.templateId,
      ),
      isTrue,
    );
  });

  test('graph coordinator ingests only when adapters accept', () {
    final builtIn = BuiltInAddonRegistry.create();
    final unchanged = builtIn.graphCoordinator.ingest(
      ChatEntityGraph.empty,
      'hello there',
    );
    expect(unchanged.nodes, isEmpty);

    final graph = builtIn.graphCoordinator.ingest(
      ChatEntityGraph.empty,
      'Niva Bupa Claim ID 9001001',
    );
    expect(graph.nodes, isNotEmpty);
  });

  test('firstUnofferedJourney surfaces car purchase via adapter projections',
      () async {
    final builtIn = BuiltInAddonRegistry.create();
    final graph = (await builtIn.graphCoordinator.ingestWithAddonPatches(
      ChatEntityGraph.empty,
      'Shortlisted Honda City, budget 12 lakh, parking plan in society basement.',
    )).graph;

    final journey = builtIn.graphCoordinator.firstUnofferedJourney(graph);
    expect(journey, isNotNull);
    expect(journey!.templateId, CarPurchaseGraphAdapter.templateId);
    expect(journey.isOfferable, isTrue);
  });

  test('firstUnofferedJourney preserves insurance-before-hospital ordering', () {
    final builtIn = BuiltInAddonRegistry.create();
    const linker = ChatEntityLinker();
    final graph = linker.ingest(
      ChatEntityGraph.empty,
      'Niva Bupa Claim ID 9001001 after surgery at City Hospital on 2026-03-01.',
    );

    final first = builtIn.graphCoordinator.firstUnofferedJourney(graph);
    expect(first?.templateId, InsurancePlannerGraphAdapter.templateId);
  });

  test('formatPending uses adapter assessments for missing fields', () {
    final builtIn = BuiltInAddonRegistry.create();
    const linker = ChatEntityLinker();
    final graph = linker.ingest(
      ChatEntityGraph.empty,
      'Niva Bupa reimbursement Claim ID 9001001 via Policybazaar.',
    );

    final markdown = builtIn.graphCoordinator.formatPending(
      graph: graph,
      query: "What's pending on my claim?",
    );
    expect(markdown, contains('Stored for'));
    expect(markdown, contains('Not on the graph yet'));
  });
}
