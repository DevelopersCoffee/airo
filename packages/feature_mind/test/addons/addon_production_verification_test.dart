import 'package:core_ai/core_ai.dart';
import 'package:core_domain/core_domain.dart';
import 'package:feature_mind/src/addons/built_in_addon_registry.dart';
import 'package:feature_mind/src/addons/graph_workflow/insurance_planner_graph_adapter.dart';
import 'package:feature_mind/src/agent_chat/data/connectors/life_track_record_connector.dart';
import 'package:feature_mind/src/agent_chat/domain/models/chat_entity_graph.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _SpyGraphAdapter implements GraphWorkflowAddonAdapter {
  _SpyGraphAdapter(this._id);

  final AddonId _id;
  int acceptsCalls = 0;
  int extractCalls = 0;

  @override
  AddonIdentity get identity =>
      AddonIdentity(id: _id, version: '1.0.0');

  @override
  bool accepts(GraphIngestContext input) {
    acceptsCalls++;
    return true;
  }

  @override
  Future<EntityGraphPatch> extract(GraphIngestContext input) async {
    extractCalls++;
    return const EntityGraphPatch();
  }

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

class _MockLifeTrackRepository extends Mock implements LifeTrackRepository {}

void main() {
  test('disabled graph add-on receives zero eligible adapter calls', () {
    final registry = AddonRegistry();
    final spy = _SpyGraphAdapter(AddonId('spy-graph'));
    registry.registerBuiltIn(
      manifest: AddonManifest.fromJson({
        'schema_version': '1.0',
        'id': 'spy-graph',
        'version': '1.0.0',
        'behaviors': ['graph_workflow'],
        'capabilities': ['conversation.current_turn'],
        'tools': [],
        'adapter': {'kind': 'required_built_in', 'contract': 'graph_workflow_v1'},
        'workflow': {
          'subject_kind': 'spy',
          'template_id': 'spy_template_v1',
        },
      }),
      graphAdapter: spy,
    );
    registry.setEligibility(
      'spy-graph',
      const AddonEligibility(enabled: false),
    );

    expect(registry.eligibleGraphAdapters(), isEmpty);
    expect(spy.acceptsCalls, 0);
    expect(spy.extractCalls, 0);
  });

  test('graph workflow ingest is deterministic without model or network',
      () async {
    final builtIn = BuiltInAddonRegistry.create();
    final graph = await builtIn.graphCoordinator.ingestWithAddonPatches(
      ChatEntityGraph.empty,
      'Niva Bupa Claim ID 9001001 via Policybazaar. All documents received.',
    );
    expect(graph.nodes, isNotEmpty);
    final projections = builtIn.graphCoordinator.workflowProjections(graph);
    expect(
      projections.any(
        (item) => item.templateId == InsurancePlannerGraphAdapter.templateId,
      ),
      isTrue,
    );
  });

  test('record connector rejects legacy confirmed without user_confirm', () async {
    final connector = LifeTrackRecordConnector(
      repository: _MockLifeTrackRepository(),
      resolveTemplate: (_) async => null,
    );

    final result = await connector.execute({
      'title': 'Test journey',
      'template_id': 'insurance_claim_v1',
      'facts': {'Claim ID': 'ABC123'},
      'confirmed': true,
    });

    expect(result.isError, isTrue);
    expect(result.errorCode, 'confirmation_required');
  });

  test('record connector rejects confirmed with wrong source token', () async {
    final connector = LifeTrackRecordConnector(
      repository: _MockLifeTrackRepository(),
      resolveTemplate: (_) async => null,
    );

    final result = await connector.execute({
      'title': 'Test journey',
      'template_id': 'insurance_claim_v1',
      'facts': {'Claim ID': 'ABC123'},
      'confirmed': true,
      'source': 'legacy',
    });

    expect(result.isError, isTrue);
    expect(result.errorCode, 'confirmation_required');
  });
}
