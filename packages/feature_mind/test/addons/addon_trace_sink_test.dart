import 'dart:convert';

import 'package:core_ai/core_ai.dart';
import 'package:core_domain/core_domain.dart';
import 'package:feature_mind/src/addons/addon_trace_redaction.dart';
import 'package:feature_mind/src/agent_chat/data/connectors/life_track_record_connector.dart';
import 'package:feature_mind/src/agent_chat/data/services/chat_turn_trace_store.dart';
import 'package:feature_mind/src/agent_chat/domain/models/agent_skill.dart';
import 'package:feature_mind/src/agent_chat/domain/services/agent_connector_registry.dart';
import 'package:feature_mind/src/agent_chat/domain/services/agent_skill_orchestrator.dart';
import 'package:feature_mind/src/agent_chat/domain/services/agent_skill_registry.dart';
import 'package:feature_mind/src/agent_chat/domain/services/confirmation_token_store.dart';
import 'package:feature_mind/src/agent_chat/domain/services/lifetrack_confirmation_token_service.dart';
import 'package:feature_mind/src/runtime/models/log_models.dart';
import '../support/recording_operation_log.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockLifeTrackRepository extends Mock implements LifeTrackRepository {}

void main() {
  setUp(() {
    AddonInvocationEpoch.instance.resetForTesting();
  });

  test('orchestrator traces omit LifeTrack fact values', () async {
    final repository = _MockLifeTrackRepository();
    when(() => repository.listTracks()).thenAnswer(
      (_) async => const Ok(<LifeTrack>[]),
    );

    final registry = AgentSkillRegistry(skills: [
      AgentSkill(
        id: 'record-insurance-claim',
        name: 'Record claim',
        description: 'Record',
        instructions: 'Record insurance claim facts locally.',
        enabled: true,
        tools: ['record_lifetrack_facts'],
        capabilities: const [SkillCapability.lifeTrackWrite],
        lifeTrackTemplateId: 'insurance_claim_v1',
      ),
    ]);

    final connector = LifeTrackRecordConnector(
      repository: repository,
      resolveTemplate: (_) async => LifeTrackTemplate(
        templateId: 'insurance_claim_v1',
        title: 'Insurance',
        description: 'Test',
        category: LifeTrackCategory.insurance,
        version: '1',
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
      ),
    );

    final orchestrator = AgentSkillOrchestrator(
      skillRegistry: registry,
      connectorRegistry: AgentConnectorRegistry(connectors: [connector]),
      modelClient: _RecordingModelClient(),
    );

    final result = await orchestrator.run(
      'Record Niva claim ABC123 on this device',
    );

    expect(result.handled, isTrue);
    final executeTrace = result.traces.firstWhere(
      (trace) => trace.title == 'Execute action',
    );
    expect(executeTrace.parameters.containsKey('facts'), isFalse);
    expect(jsonEncode(executeTrace.parameters), isNot(contains('ABC123')));
  });

  test('data volume measurement uses redacted connector payloads', () async {
    final repository = _MockLifeTrackRepository();
    when(() => repository.listTracks()).thenAnswer(
      (_) async => const Ok(<LifeTrack>[]),
    );

    final registry = AgentSkillRegistry(skills: [
      AgentSkill(
        id: 'record-insurance-claim',
        name: 'Record claim',
        description: 'Record',
        instructions: 'Record insurance claim facts locally.',
        enabled: true,
        tools: ['record_lifetrack_facts'],
        capabilities: const [SkillCapability.lifeTrackWrite],
        lifeTrackTemplateId: 'insurance_claim_v1',
      ),
    ]);

    final connector = LifeTrackRecordConnector(
      repository: repository,
      resolveTemplate: (_) async => LifeTrackTemplate(
        templateId: 'insurance_claim_v1',
        title: 'Insurance',
        description: 'Test',
        category: LifeTrackCategory.insurance,
        version: '1',
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
      ),
    );

    final log = RecordingOperationLog();
    await log.append(
      kind: MindOpKind.note,
      title: 'fixture op',
      contextId: 'trace-sink',
    );

    final orchestrator = AgentSkillOrchestrator(
      skillRegistry: registry,
      connectorRegistry: AgentConnectorRegistry(connectors: [connector]),
      modelClient: _RecordingModelClient(),
      operationLogPort: log,
    );

    final result = await orchestrator.run(
      'Record Niva claim ABC123 on this device',
    );

    expect(result.handled, isTrue);
    final executeTrace = result.traces.firstWhere(
      (trace) => trace.title == 'Execute action',
    );
    final redactedPayload = jsonEncode(executeTrace.parameters);
    expect(redactedPayload, isNot(contains('ABC123')));
    expect(executeTrace.dataVolume, isNull);
    expect(log.appended.every((op) => !op.detail.contains('ABC123')), isTrue);
  });

  test('late LifeTrack redemption returns addon_invocation_cancelled', () async {
    final repository = _MockLifeTrackRepository();
    when(() => repository.listTracks()).thenAnswer(
      (_) async => const Ok(<LifeTrack>[]),
    );

    final tokens = LifeTrackConfirmationTokenService(
      store: InMemoryConfirmationTokenStore(),
    );
    final payload = {
      'title': 'Niva claim',
      'template_id': 'insurance_claim_v1',
      'facts': {'Claim ID': 'ABC123'},
    };
    final token = await tokens.issue(
      destinationTool: 'record_lifetrack_facts',
      payload: payload,
    );
    AddonInvocationEpoch.instance.bump();

    final connector = LifeTrackRecordConnector(
      repository: repository,
      resolveTemplate: (_) async => LifeTrackTemplate(
        templateId: 'insurance_claim_v1',
        title: 'Insurance',
        description: 'Test',
        category: LifeTrackCategory.insurance,
        version: '1',
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
      ),
      confirmationTokens: tokens,
    );

    final result = await connector.execute({
      'title': 'Niva claim',
      'template_id': 'insurance_claim_v1',
      'facts': payload['facts'],
      'confirmation_token': token,
    });

    expect(result.isError, isTrue);
    expect(result.errorCode, AddonInvocationEpoch.cancelledCode);
  });

  test('chat turn trace store redacts trajectory summaries on upsert', () async {
    SharedPreferences.setMockInitialValues({});
    final store = ChatTurnTraceStore(
      preferences: await SharedPreferences.getInstance(),
    );
    final trajectory = AiTrajectoryTraceBuilder(runId: 'run-claim-1')
        .error(
          code: AddonInvocationEpoch.cancelledCode,
          summary: 'Claim ID ABC123 for Niva Bupa',
        )
        .build();
    final trace = ChatTurnTrace(
      runId: 'run-claim-1',
      startedAt: DateTime.utc(2026, 8, 23),
      lifecycle: ChatTurnLifecycle.failed,
      stopReason: ChatTurnStopReason.engineError,
      runtimeId: 'offline-qwen',
      routing: ChatTurnRouting.local,
      constraint: ChatTurnConstraint.none,
      inertia: const [],
      stats: ChatTurnStats.empty,
      trajectory: trajectory,
    );

    await store.upsert(trace);
    final loaded = await store.byRunId('run-claim-1');
    expect(loaded, isNotNull);
    final storedJson = jsonEncode(loaded!.toJson());
    expect(storedJson, isNot(contains('ABC123')));
    expect(
      AddonTraceRedaction.redactTraceForPersistence(trace).trajectory
          .nodes
          .single
          .summary,
      isNot(contains('ABC123')),
    );
  });
}

class _RecordingModelClient implements AgentSkillModelClient {
  @override
  Future<String?> selectSkill({
    required String prompt,
    required List<AgentSkill> enabledSkills,
  }) async =>
      'record-insurance-claim';

  @override
  Future<SkillModelAction?> nextAction({
    required String prompt,
    required AgentSkill skill,
    required List<Map<String, dynamic>> toolResults,
  }) async {
    if (toolResults.isEmpty) {
      return SkillModelAction.toolCall(
        tool: 'record_lifetrack_facts',
        arguments: {
          'title': 'Niva claim',
          'template_id': 'insurance_claim_v1',
          'facts': {'Claim ID': 'ABC123'},
        },
      );
    }
    return const SkillModelAction.finalAnswer('Saved locally.');
  }
}
