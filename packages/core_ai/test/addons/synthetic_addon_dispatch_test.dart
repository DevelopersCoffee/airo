import 'package:core_ai/core_ai.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter_test/flutter_test.dart';

import 'synthetic_generative_adapter.dart';
import 'synthetic_graph_workflow_adapter.dart';

AddonManifest _generativeManifest() => AddonManifest.fromJson({
  'schema_version': '1.0',
  'id': 'sample-generative',
  'version': '1.0.0',
  'behaviors': ['generative'],
  'capabilities': ['conversation.current_turn'],
  'tools': [],
  'adapter': {'kind': 'required_built_in', 'contract': 'generative_v1'},
});

AddonManifest _graphManifest() => AddonManifest.fromJson({
  'schema_version': '1.0',
  'id': 'sample-graph',
  'version': '1.0.0',
  'behaviors': ['graph_workflow'],
  'capabilities': ['conversation.current_turn', 'graph.addon_scope.read'],
  'tools': ['query_entity_graph'],
  'adapter': {'kind': 'required_built_in', 'contract': 'graph_workflow_v1'},
  'workflow': {'subject_kind': 'subject'},
});

void main() {
  test('synthetic generative adapter routes through registry without host switch',
      () {
    final registry = AddonRegistry();
    final generative = SyntheticGenerativeAdapter();
    final manifest = _generativeManifest();

    registry.registerBuiltIn(
      manifest: manifest,
      generativeAdapter: generative,
    );
    registry.setEligibility(
      manifest.id.value,
      const AddonEligibility(
        enabled: true,
        grantedScopes: {'conversation.current_turn'},
      ),
    );

    final conversation = const AddonConversation(
      currentPrompt: 'please sample-trigger now',
    );

    final accepting = registry
        .eligibleGenerativeAdapters()
        .where((adapter) => adapter.accepts(conversation))
        .toList(growable: false);

    expect(accepting, hasLength(1));
    final prompt = accepting.single.buildPrompt(conversation);
    expect(prompt.userPrompt, contains('sample-trigger'));
    expect(prompt.systemInstruction, 'sample-system');
  });

  test('synthetic graph adapter extracts and projects through registry', () async {
    final registry = AddonRegistry();
    final graphAdapter = SyntheticGraphWorkflowAdapter();
    final manifest = _graphManifest();

    registry.registerBuiltIn(
      manifest: manifest,
      graphAdapter: graphAdapter,
    );
    registry.setEligibility(
      manifest.id.value,
      const AddonEligibility(
        enabled: true,
        grantedScopes: {'conversation.current_turn'},
      ),
    );

    final context = GraphIngestContext(
      text: 'please sample-extract subject',
      graph: EntityGraph.empty,
      turnRevision: 'turn-1',
    );

    final adapters = registry.eligibleGraphAdapters();
    final accepting = adapters.where((adapter) => adapter.accepts(context));
    expect(accepting, hasLength(1));

    final patch = await accepting.single.extract(context);
    final merged = context.graph.upsert(
      incomingNodes: patch.nodes,
      incomingEdges: patch.edges,
      mentionedIds: patch.mentionedNodeIds,
    );

    final projections = accepting.single.project(merged).toList(growable: false);
    expect(projections, hasLength(1));
    expect(projections.single.templateId, 'sample-template');
    expect(projections.single.isOfferable, isTrue);

    final pending = accepting.single.assessPending(
      merged,
      projections.single,
    );
    expect(pending.missingRequired, ['field_b']);
  });
}
