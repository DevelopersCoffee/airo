import 'package:feature_mind/src/agent_chat/domain/models/chat_entity_graph.dart';
import 'package:core_ai/core_ai.dart';
import 'package:core_domain/core_domain.dart';
import 'package:feature_mind/src/addons/built_in_addon_registry.dart';
import 'package:feature_mind/src/addons/graph_workflow/car_purchase_graph_adapter.dart';
import 'package:feature_mind/src/addons/graph_workflow/university_admission_graph_adapter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('car adapter rejects generic need-only prompts', () {
    final adapter = CarPurchaseGraphAdapter();
    expect(
      adapter.accepts(
        GraphIngestContext(text: 'I need a car', graph: EntityGraph.empty),
      ),
      isFalse,
    );
  });

  test('car adapter accepts vehicle plus budget and projects offerable journey',
      () async {
    final builtIn = BuiltInAddonRegistry.create();
    final graph = (await builtIn.graphCoordinator.ingestWithAddonPatches(
      ChatEntityGraph.empty,
      'Shortlisted Toyota Camry, budget around 25 lakh, parking plan in basement.',
    )).graph;

    final projections = builtIn.graphCoordinator.workflowProjections(graph);
    expect(
      projections.any(
        (item) =>
            item.identity.id.value == CarPurchaseGraphAdapter.addonId &&
            item.templateId == CarPurchaseGraphAdapter.templateId &&
            item.offer.kind == OfferDecisionKind.offerable,
      ),
      isTrue,
    );
  });

  test('university adapter rejects info-only program questions', () {
    final adapter = UniversityAdmissionGraphAdapter();
    expect(
      adapter.accepts(
        GraphIngestContext(
          text: 'What programs does MIT offer?',
          graph: EntityGraph.empty,
        ),
      ),
      isFalse,
    );
  });

  test('university adapter accepts applying fixture and projects journey',
      () async {
    final builtIn = BuiltInAddonRegistry.create();
    final graph = (await builtIn.graphCoordinator.ingestWithAddonPatches(
      ChatEntityGraph.empty,
      'I am applying to MIT for Fall 2027.',
    )).graph;

    final projections = builtIn.graphCoordinator.workflowProjections(graph);
    expect(
      projections.any(
        (item) =>
            item.identity.id.value ==
                UniversityAdmissionGraphAdapter.addonId &&
            item.templateId == UniversityAdmissionGraphAdapter.templateId &&
            item.offer.kind == OfferDecisionKind.offerable,
      ),
      isTrue,
    );
  });
}
