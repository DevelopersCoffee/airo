import 'dart:convert';

import 'package:core_domain/core_domain.dart';
import 'package:feature_mind/src/agent_chat/data/connectors/life_track_record_connector.dart';
import 'package:feature_mind/src/agent_chat/domain/models/agent_skill.dart';
import 'package:feature_mind/src/agent_chat/domain/services/agent_connector_registry.dart';
import 'package:feature_mind/src/agent_chat/domain/services/agent_skill_orchestrator.dart';
import 'package:feature_mind/src/agent_chat/domain/services/agent_skill_registry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockLifeTrackRepository extends Mock implements LifeTrackRepository {}

void main() {
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
