import 'package:core_ai/core_ai.dart';
import 'package:core_domain/core_domain.dart';
import 'package:feature_mind/src/addons/addon_lifecycle_gate.dart';
import 'package:feature_mind/src/addons/built_in_addon_registry.dart';
import 'package:feature_mind/src/addons/graph_workflow/graph_workflow_coordinator.dart';
import 'package:feature_mind/src/agent_chat/data/repositories/chat_entity_graph_session.dart';
import 'package:feature_mind/src/agent_chat/domain/services/confirmation_token_store.dart';
import 'package:feature_mind/src/agent_chat/domain/services/lifetrack_confirmation_token_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _SpyGraphAdapter implements GraphWorkflowAddonAdapter {
  int extractCalls = 0;

  @override
  AddonIdentity get identity =>
      const AddonIdentity(id: AddonId('spy-lifecycle'), version: '1.0.0');

  @override
  bool accepts(GraphIngestContext input) => true;

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

void main() {
  test('disabled add-on receives zero extract calls during ingest', () async {
    final registry = AddonRegistry();
    final spy = _SpyGraphAdapter();
    registry.registerBuiltIn(
      manifest: AddonManifest.fromJson({
        'schema_version': '1.0',
        'id': 'spy-lifecycle',
        'version': '1.0.0',
        'behaviors': ['graph_workflow'],
        'capabilities': ['conversation.current_turn'],
        'tools': ['query_entity_graph'],
        'adapter': {
          'kind': 'required_built_in',
          'contract': 'graph_workflow_v1',
        },
        'workflow': {'subject_kind': 'spy'},
      }),
      graphAdapter: spy,
    );
    BuiltInAddonRegistry.updateEligibility(
      registry,
      'spy-lifecycle',
      const AddonEligibility(enabled: false),
    );

    final session = ChatEntityGraphSession(
      graphCoordinator: GraphWorkflowCoordinator(registry),
    );
    session.bindConversation('chat-disabled');
    await session.ingest('Niva claim ABC123');

    expect(spy.extractCalls, 0);
    expect((await session.ensureLoaded()).nodes, isEmpty);
  });

  test('revoke invalidates confirmation token before redemption', () async {
    final tokens = LifeTrackConfirmationTokenService(
      store: InMemoryConfirmationTokenStore(),
    );
    final gate = AddonLifecycleGate(confirmationTokens: tokens);
    final payload = {
      'title': 'Claim',
      'template_id': 'insurance_claim_v1',
      'facts': {'Claim ID': '1'},
    };
    final token = await tokens.issue(
      destinationTool: 'record_lifetrack_facts',
      payload: payload,
    );
    gate.onEligibilityChanged(const AddonEligibility(enabled: false));
    expect(
      await tokens.validateAndConsume(
        token: token,
        destinationTool: 'record_lifetrack_facts',
        payload: payload,
      ),
      isNotNull,
    );
  });
}
