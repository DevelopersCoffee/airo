import 'package:core_ai/core_ai.dart';
import 'package:core_domain/core_domain.dart';
import 'package:feature_mind/src/addons/addon_lifecycle_gate.dart';
import 'package:feature_mind/src/addons/built_in_addon_registry.dart';
import 'package:feature_mind/src/addons/draft_diet_plan/draft_diet_plan_adapter.dart';
import 'package:feature_mind/src/addons/graph_workflow/graph_workflow_coordinator.dart';
import 'package:feature_mind/src/addons/graph_workflow/insurance_planner_graph_adapter.dart';
import 'package:feature_mind/src/agent_chat/data/connectors/life_track_record_connector.dart';
import 'package:feature_mind/src/agent_chat/data/repositories/chat_entity_graph_session.dart';
import 'package:feature_mind/src/agent_chat/domain/models/chat_entity_graph.dart';
import 'package:feature_mind/src/agent_chat/data/services/assistant_chat_context_builder.dart';
import 'package:feature_mind/src/agent_chat/domain/services/lifetrack_confirmation_token_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockLifeTrackRepository extends Mock implements LifeTrackRepository {}

class _ProjectionSpyAdapter implements GraphWorkflowAddonAdapter {
  _ProjectionSpyAdapter(
    this.id, {
    this.onProject,
    this.onAssess,
  });

  final AddonId id;
  final void Function()? onProject;
  final void Function()? onAssess;
  int projectCalls = 0;
  int assessCalls = 0;

  @override
  AddonIdentity get identity => AddonIdentity(id: id, version: '1.0.0');

  @override
  bool accepts(GraphIngestContext input) => true;

  @override
  Future<EntityGraphPatch> extract(GraphIngestContext input) async =>
      const EntityGraphPatch();

  @override
  Iterable<WorkflowProjection> project(EntityGraph graph) {
    projectCalls++;
    onProject?.call();
    return [
      WorkflowProjection(
        identity: identity,
        subjectNodeId: 'node-${id.value}',
        destinationKind: 'lifetrack',
        templateId: 'spy_template_v1',
        templateVersion: '1',
        title: 'Spy journey',
        factsByFieldId: {},
        identityKey: 'spy-${id.value}',
        offer: const OfferDecision(
          kind: OfferDecisionKind.offerable,
          reason: 'test',
        ),
      ),
    ];
  }

  @override
  PendingAssessment assessPending(
    EntityGraph graph,
    WorkflowProjection projection,
  ) {
    assessCalls++;
    onAssess?.call();
    return PendingAssessment(
      identity: identity,
      subjectNodeId: projection.subjectNodeId,
      storedFacts: {},
      missingRequired: ['Claim ID'],
      missingOptional: [],
    );
  }
}

void main() {
  setUpAll(() {
    registerFallbackValue(
      LifeTrack(
        id: 'fallback',
        title: 'fallback',
        category: LifeTrackCategory.insurance,
        status: TrackStatus.active,
        milestones: const [],
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
        templateId: 'insurance_claim_v1',
      ),
    );
  });

  setUp(() {
    AddonInvocationEpoch.instance.resetForTesting();
  });

  test('revoke during projection skips remaining adapters', () {
    final registry = AddonRegistry();
    final first = _ProjectionSpyAdapter(
      AddonId('projection-first'),
      onProject: () => AddonInvocationEpoch.instance.bump(),
    );
    final second = _ProjectionSpyAdapter(AddonId('projection-second'));
    for (final spy in [first, second]) {
      registry.registerBuiltIn(
        manifest: AddonManifest.fromJson({
          'schema_version': '1.0',
          'id': spy.identity.id.value,
          'version': '1.0.0',
          'behaviors': ['graph_workflow'],
          'capabilities': ['conversation.current_turn'],
          'tools': [],
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
        spy.identity.id.value,
        const AddonEligibility(
          enabled: true,
          grantedScopes: {'conversation.current_turn'},
        ),
      );
    }

    final coordinator = GraphWorkflowCoordinator(registry);
    final projections = coordinator.workflowProjections(ChatEntityGraph.empty);

    expect(first.projectCalls, 1);
    expect(second.projectCalls, 0);
    expect(projections.length, 1);
  });

  test('revoke during pending assessment skips remaining adapters', () {
    final registry = AddonRegistry();
    final first = _ProjectionSpyAdapter(
      AddonId('pending-first'),
      onAssess: () => AddonInvocationEpoch.instance.bump(),
    );
    final second = _ProjectionSpyAdapter(AddonId('pending-second'));
    for (final spy in [first, second]) {
      registry.registerBuiltIn(
        manifest: AddonManifest.fromJson({
          'schema_version': '1.0',
          'id': spy.identity.id.value,
          'version': '1.0.0',
          'behaviors': ['graph_workflow'],
          'capabilities': ['conversation.current_turn'],
          'tools': [],
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
        spy.identity.id.value,
        const AddonEligibility(
          enabled: true,
          grantedScopes: {'conversation.current_turn'},
        ),
      );
    }

    final coordinator = GraphWorkflowCoordinator(registry);
    final assessments = coordinator.pendingAssessments(ChatEntityGraph.empty);

    expect(first.assessCalls, 1);
    expect(second.assessCalls, 0);
    expect(assessments.length, 1);
  });

  test('revoked generative add-on returns no plan and cancels stale review',
      () {
    final builtIn = BuiltInAddonRegistry.create();
    final history = [
      const AssistantChatContextMessage(
        text: 'Make me a 7 day vegetarian diet plan',
        isUser: true,
      ),
    ];
    final plan = builtIn.coordinator.planFor(
      currentPrompt: 'Make me a 7 day vegetarian diet plan',
      history: history,
    );
    expect(plan, isNotNull);

    BuiltInAddonRegistry.updateEligibility(
      builtIn.registry,
      DraftDietPlanAdapter.addonId,
      const AddonEligibility(enabled: false),
    );

    expect(
      builtIn.coordinator.planFor(
        currentPrompt: 'Make me a 7 day vegetarian diet plan',
        history: history,
      ),
      isNull,
    );

    final review = builtIn.coordinator.reviewOutput(
      plan: plan!,
      output: "Day 1: oats",
      alreadyRetried: false,
    );
    expect(review.invalid, isTrue);
    expect(review.output, contains('disabled'));
  });

  test('revoke clears session graph and blocks new ingest projections', () async {
    final builtIn = BuiltInAddonRegistry.create();
    final session = ChatEntityGraphSession(
      graphCoordinator: builtIn.graphCoordinator,
    );
    session.bindConversation('chat-revoke');
    await session.ingest(
      'Niva Bupa Claim ID 9001001 via Policybazaar. All documents received.',
    );
    expect((await session.ensureLoaded()).nodes, isNotEmpty);

    BuiltInAddonRegistry.updateEligibility(
      builtIn.registry,
      InsurancePlannerGraphAdapter.addonId,
      const AddonEligibility(enabled: false, revoked: true),
    );
    AddonLifecycleGate(graphSession: session).onEligibilityChanged(
      const AddonEligibility(enabled: false, revoked: true),
    );

    expect(session.graph.nodes, isEmpty);
    await session.ingest('Another claim ABC999');
    expect(builtIn.graphCoordinator.workflowProjections(session.graph), isEmpty);
  });

  test('insurance pipeline ingest projection pending confirm save', () async {
    final builtIn = BuiltInAddonRegistry.create();
    final ingest = await builtIn.graphCoordinator.ingestWithAddonPatches(
      ChatEntityGraph.empty,
      'Niva Bupa Claim ID 9001001 via Policybazaar. All documents received.',
    );
    expect(ingest.cancelled, isFalse);
    expect(ingest.graph.nodes, isNotEmpty);

    final projections = builtIn.graphCoordinator.workflowProjections(
      ingest.graph,
    );
    expect(projections, isNotEmpty);

    final pending = builtIn.graphCoordinator.formatPending(
      graph: ingest.graph,
      query: 'what is still missing on my claim?',
    );
    expect(pending.toLowerCase(), contains('not on the graph yet'));

    final repository = _MockLifeTrackRepository();
    when(() => repository.listTracks()).thenAnswer(
      (_) async => const Ok(<LifeTrack>[]),
    );
    when(() => repository.createTrack(any())).thenAnswer(
      (invocation) async => Ok(invocation.positionalArguments[0] as LifeTrack),
    );

    final tokens = LifeTrackConfirmationTokenService(
      now: () => DateTime.utc(2026, 8, 22),
    );
    final connector = LifeTrackRecordConnector(
      repository: repository,
      resolveTemplate: (_) async => _pipelineTemplate,
      confirmationTokens: tokens,
      newTrackId: () => 'lt-pipeline-1',
    );

    final preview = await connector.execute({
      'title': 'Niva claim',
      'template_id': 'insurance_claim_v1',
      'facts': {'Claim ID': '9001001'},
    });
    expect(preview.errorCode, 'confirmation_required');
    final token = preview.data['confirmation_token'] as String;

    final saved = await connector.execute({
      'title': 'Niva claim',
      'template_id': 'insurance_claim_v1',
      'facts': {'Claim ID': '9001001'},
      'confirmation_token': token,
    });
    expect(saved.isError, isFalse);
    verify(() => repository.createTrack(any())).called(1);
  });
}

const _pipelineTemplate = LifeTrackTemplate(
  templateId: 'insurance_claim_v1',
  title: 'Insurance Claim Tracking Template',
  description: 'Test',
  category: LifeTrackCategory.insurance,
  version: '1.1',
  milestones: [
    MilestoneTemplate(
      name: 'Phase 1',
      objective: 'Record',
      tasks: [
        ActionItemTemplate(
          summary: 'Record claim',
          requirements: [
            InputRequirementTemplate(
              label: 'Claim ID',
              type: FieldType.text,
              isRequired: true,
            ),
          ],
        ),
      ],
    ),
  ],
);
