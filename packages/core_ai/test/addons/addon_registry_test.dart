import 'package:core_ai/core_ai.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter_test/flutter_test.dart';

AddonManifest _sampleGenerativeManifest() => AddonManifest.fromJson({
  'schema_version': '1.0',
  'id': 'sample-generative',
  'version': '1.0.0',
  'behaviors': ['generative'],
  'capabilities': ['conversation.current_turn'],
  'tools': [],
  'adapter': {'kind': 'required_built_in', 'contract': 'generative_v1'},
});

AddonManifest _sampleGraphManifest({int priority = 0}) =>
    AddonManifest.fromJson({
      'schema_version': '1.0',
      'id': 'sample-graph',
      'version': '1.0.0',
      'behaviors': ['graph_workflow'],
      'capabilities': ['conversation.current_turn', 'graph.addon_scope.read'],
      'tools': ['query_entity_graph'],
      'adapter': {
        'kind': 'required_built_in',
        'contract': 'graph_workflow_v1',
      },
      'workflow': {
        'template_asset': 'template.json',
        'subject_kind': 'subject',
      },
      if (priority != 0) 'built_in_priority': priority,
    });

class _SpyGenerativeAdapter implements GenerativeAddonAdapter {
  _SpyGenerativeAdapter(this.id, {this.onAccepts, this.onBuild});

  final AddonId id;
  int acceptsCalls = 0;
  int buildCalls = 0;
  bool Function(AddonConversation input)? onAccepts;
  AddonPrompt Function(AddonConversation input)? onBuild;

  @override
  AddonIdentity get identity => AddonIdentity(id: id, version: '1.0.0');

  @override
  bool accepts(AddonConversation input) {
    acceptsCalls++;
    return onAccepts?.call(input) ?? false;
  }

  @override
  AddonPrompt buildPrompt(AddonConversation input) {
    buildCalls++;
    return onBuild?.call(input) ??
        const AddonPrompt(systemInstruction: 'sys', userPrompt: 'user');
  }

  @override
  AddonEvaluation evaluate(String output) =>
      const AddonEvaluation(kind: AddonEvaluationKind.valid);
}

class _SpyGraphAdapter implements GraphWorkflowAddonAdapter {
  _SpyGraphAdapter(this.id, {this.onAccepts});

  final AddonId id;
  int acceptsCalls = 0;
  bool Function(GraphIngestContext input)? onAccepts;

  @override
  AddonIdentity get identity => AddonIdentity(id: id, version: '1.0.0');

  @override
  bool accepts(GraphIngestContext input) {
    acceptsCalls++;
    return onAccepts?.call(input) ?? false;
  }

  @override
  Future<EntityGraphPatch> extract(GraphIngestContext input) async =>
      const EntityGraphPatch();

  @override
  Iterable<WorkflowProjection> project(EntityGraph graph) => const [];

  @override
  PendingAssessment assessPending(
    EntityGraph graph,
    WorkflowProjection projection,
  ) => PendingAssessment(
    identity: identity,
    subjectNodeId: projection.subjectNodeId,
    storedFacts: {},
    missingRequired: [],
    missingOptional: [],
  );
}

void main() {
  test('duplicate registration fails closed', () {
    final registry = AddonRegistry();
    final manifest = _sampleGenerativeManifest();
    final adapter = _SpyGenerativeAdapter(manifest.id);

    registry.registerBuiltIn(
      manifest: manifest,
      generativeAdapter: adapter,
    );

    expect(
      () => registry.registerBuiltIn(
        manifest: manifest,
        generativeAdapter: adapter,
      ),
      throwsA(isA<AddonRegistrationException>()),
    );
  });

  test('pinned add-on is ordered before unpinned with same priority', () {
    final registry = AddonRegistry();
    final low = _sampleGraphManifest();
    final high = AddonManifest.fromJson({
      'schema_version': '1.0',
      'id': 'sample-graph-b',
      'version': '1.0.0',
      'behaviors': ['graph_workflow'],
      'capabilities': ['conversation.current_turn'],
      'tools': ['query_entity_graph'],
      'workflow': {'subject_kind': 'subject'},
    });

    registry.registerBuiltIn(
      manifest: low,
      graphAdapter: _SpyGraphAdapter(low.id),
    );
    registry.registerBuiltIn(
      manifest: high,
      graphAdapter: _SpyGraphAdapter(high.id),
    );

    registry.setEligibility(
      low.id.value,
      const AddonEligibility(
        enabled: true,
        grantedScopes: {'conversation.current_turn'},
      ),
    );
    registry.setEligibility(
      high.id.value,
      const AddonEligibility(
        enabled: true,
        pinned: true,
        grantedScopes: {'conversation.current_turn'},
      ),
    );

    final ordered = registry.eligibleManifests(
      behavior: AddonBehaviorKind.graphWorkflow,
    );
    expect(ordered.first.id.value, 'sample-graph-b');
  });

  test('disabled add-on receives zero adapter calls', () {
    final registry = AddonRegistry();
    final manifest = _sampleGenerativeManifest();
    final spy = _SpyGenerativeAdapter(
      manifest.id,
      onAccepts: (_) => true,
    );

    registry.registerBuiltIn(
      manifest: manifest,
      generativeAdapter: spy,
    );
    registry.setEligibility(
      manifest.id.value,
      const AddonEligibility(enabled: false),
    );

    final adapters = registry.eligibleGenerativeAdapters();
    expect(adapters, isEmpty);
    expect(spy.acceptsCalls, 0);
  });
}
