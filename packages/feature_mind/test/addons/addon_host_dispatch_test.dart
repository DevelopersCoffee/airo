import 'package:core_ai/core_ai.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:feature_mind/src/addons/addon_host_dispatch.dart';

class _HostGenerativeAdapter implements GenerativeAddonAdapter {
  @override
  AddonIdentity get identity =>
      const AddonIdentity(id: AddonId('sample-generative'), version: '1.0.0');

  @override
  bool accepts(AddonConversation input) =>
      input.currentPrompt.contains('sample-trigger');

  @override
  AddonPrompt buildPrompt(AddonConversation input) => AddonPrompt(
    systemInstruction: 'host-system',
    userPrompt: input.currentPrompt,
  );

  @override
  AddonEvaluation evaluate(String output) =>
      const AddonEvaluation(kind: AddonEvaluationKind.valid);
}

class _HostGraphAdapter implements GraphWorkflowAddonAdapter {
  @override
  AddonIdentity get identity =>
      const AddonIdentity(id: AddonId('sample-graph'), version: '1.0.0');

  @override
  bool accepts(GraphIngestContext input) =>
      input.text.contains('sample-extract');

  @override
  Future<EntityGraphPatch> extract(GraphIngestContext input) async =>
      EntityGraphPatch(
        nodes: [
          EntityGraphNode(
            id: 'identifier:subject-host',
            typeKey: 'identifier',
            name: 'subject',
            attributes: {'kind': 'subject'},
          ),
        ],
      );

  @override
  Iterable<WorkflowProjection> project(EntityGraph graph) {
    return graph.nodes.map(
      (node) => WorkflowProjection(
        identity: identity,
        subjectNodeId: node.id,
        destinationKind: 'lifetrack',
        templateId: 'sample-template',
        templateVersion: '1',
        title: 'host projection',
        factsByFieldId: {},
        identityKey: node.id,
        offer: const OfferDecision(kind: OfferDecisionKind.offerable),
      ),
    );
  }

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
  test('AddonHostDispatch routes generative and graph paths without ID switches',
      () async {
    final registry = AddonRegistry();
    registry.registerBuiltIn(
      manifest: AddonManifest.fromJson({
        'schema_version': '1.0',
        'id': 'sample-generative',
        'version': '1.0.0',
        'behaviors': ['generative'],
        'capabilities': ['conversation.current_turn'],
        'tools': [],
      }),
      generativeAdapter: _HostGenerativeAdapter(),
    );
    registry.registerBuiltIn(
      manifest: AddonManifest.fromJson({
        'schema_version': '1.0',
        'id': 'sample-graph',
        'version': '1.0.0',
        'behaviors': ['graph_workflow'],
        'capabilities': ['conversation.current_turn'],
        'tools': ['query_entity_graph'],
        'workflow': {'subject_kind': 'subject'},
      }),
      graphAdapter: _HostGraphAdapter(),
    );

    for (final id in ['sample-generative', 'sample-graph']) {
      registry.setEligibility(
        id,
        const AddonEligibility(
          enabled: true,
          grantedScopes: {'conversation.current_turn'},
        ),
      );
    }

    final dispatch = AddonHostDispatch(registry);

    final prompt = dispatch.buildGenerativePrompt(
      const AddonConversation(currentPrompt: 'please sample-trigger'),
    );
    expect(prompt?.systemInstruction, 'host-system');

    final patch = await dispatch.extractGraphPatch(
      GraphIngestContext(
        text: 'please sample-extract',
        graph: EntityGraph.empty,
      ),
    );
    expect(patch?.nodes.single.id, 'identifier:subject-host');

    final merged = EntityGraph.empty.upsert(
      incomingNodes: patch!.nodes,
      incomingEdges: patch.edges,
      mentionedIds: patch.mentionedNodeIds,
    );
    final projections = dispatch.projectGraph(merged);
    expect(projections.single.title, 'host projection');
  });
}
