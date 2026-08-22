import 'dart:async';

import 'package:core_ai/core_ai.dart';

import '../../domain/models/agent_skill.dart';
import '../../domain/services/agent_skill_orchestrator.dart';
import 'assistant_runtime_service.dart';

class SelectedRuntimeAgentSkillModelClient implements AgentSkillModelClient {
  SelectedRuntimeAgentSkillModelClient({
    required this._runtimeService,
    required this._selectedModelId,
  });

  final AssistantRuntimeService _runtimeService;
  final FutureOr<String?> Function() _selectedModelId;

  @override
  Future<String?> selectSkill({
    required String prompt,
    required List<AgentSkill> enabledSkills,
  }) async {
    if (enabledSkills.isEmpty) return null;
    if (!AiroPromptRegistry.skillSelect.isRegistered) return null;
    final skillList = enabledSkills
        .map((skill) => '- ${skill.id}: ${skill.description}')
        .join('\n');
    final instruction =
        '''
You are choosing whether an Airo skill should handle the user request.

Available skills:
$skillList

User request:
"$prompt"

Return JSON only:
{"skill_id":"skill-id"}

If no skill applies:
{"skill_id":null}
''';

    final response = await _generate(instruction);
    if (response == null) return null;

    final recovery = RecoveryEngine(RecoveryPolicy.skillJson);
    var selected = parseSelectedSkillId(response);
    while (selected == null) {
      if (recovery.select(RecoveryAction.retry) != RecoveryDecision.execute) {
        return null;
      }
      recovery.noteAttempt(RecoveryAction.retry);
      final retry = await _generate(instruction);
      selected = retry == null ? null : parseSelectedSkillId(retry);
    }
    if (enabledSkills.any((skill) => skill.id == selected)) return selected;
    return null;
  }

  @override
  Future<SkillModelAction?> nextAction({
    required String prompt,
    required AgentSkill skill,
    required List<Map<String, dynamic>> toolResults,
  }) async {
    final previousResults = toolResults.isEmpty ? 'none' : '$toolResults';
    final instruction =
        '''
You are executing an Airo skill.

Runtime rules:
- Return JSON only.
- You may only call tools listed in the skill.
- Do not invent tool results.
- If you need data, call a tool.
- If you have enough data, return final.

Skill:
${skill.id}

Allowed tools:
${skill.tools.map((tool) => '- $tool').join('\n')}

Instructions:
${skill.instructions}

User request:
$prompt

Previous tool results:
${ContextCompiler.wrapAsData(previousResults)}

Return either:
{"type":"tool_call","tool":"tool_name","arguments":{}}

or:
{"type":"final","message":"final answer"}
''';
    final definition = AiroPromptRegistry.skillNextAction;
    final contract = PromptQualityGate.inspectLivePrompt(
      userText: prompt,
      taskInstructions: skill.instructions,
      requiresStructuredOutput: true,
      outputContract: definition.outputSchema,
    );
    if (contract.decision == PromptGateDecision.abort) {
      return SkillModelAction.finalAnswer(
        contract.userMessage,
        schemaInvalid: true,
      );
    }
    final response = await _generate(instruction);

    if (response == null) return null;

    final recovery = RecoveryEngine(RecoveryPolicy.skillJson);
    var action = parseSkillModelAction(response);
    while (action == null) {
      if (recovery.select(RecoveryAction.retry) != RecoveryDecision.execute) {
        return SkillModelAction.finalAnswer(
          OutputSchemaGuard.userMessage(),
          schemaInvalid: true,
        );
      }
      recovery.noteAttempt(RecoveryAction.retry);
      final retry = await _generate(instruction);
      action = retry == null ? null : parseSkillModelAction(retry);
    }
    if (action.type == SkillModelActionType.toolCall &&
        !skill.tools.contains(action.tool)) {
      return null;
    }
    return action;
  }

  Future<String?> _generate(String prompt) async {
    final selectedModelId = await Future.value(_selectedModelId());
    if (selectedModelId == null) return null;

    try {
      return await _runtimeService.generateText(
        selectedModelId: selectedModelId,
        prompt: prompt,
      );
    } on AssistantRuntimeUnavailableException {
      return null;
    }
  }
}
