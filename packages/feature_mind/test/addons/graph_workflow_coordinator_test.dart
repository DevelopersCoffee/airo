import 'package:feature_mind/src/addons/built_in_addon_registry.dart';
import 'package:feature_mind/src/addons/graph_workflow/insurance_planner_graph_adapter.dart';
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
}
