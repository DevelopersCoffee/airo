import '../../../../core/services/gemini_nano_service.dart';
import '../../domain/models/agent_skill.dart';
import '../../domain/services/agent_skill_orchestrator.dart';

class GeminiAgentSkillModelClient implements AgentSkillModelClient {
  GeminiAgentSkillModelClient(this._geminiNano);

  final GeminiNanoService _geminiNano;

  @override
  Future<String?> selectSkill({
    required String prompt,
    required List<AgentSkill> enabledSkills,
  }) async {
    if (enabledSkills.isEmpty) return null;

    final skillList = enabledSkills
        .map((skill) => '- ${skill.id}: ${skill.description}')
        .join('\n');
    final response = await _geminiNano.generateContent('''
You are choosing whether an Airo skill should handle the user request.

Available skills:
$skillList

User request:
"$prompt"

Return JSON only:
{"skill_id":"skill-id"}

If no skill applies:
{"skill_id":null}
''');
    final selected = parseSelectedSkillId(response);
    if (selected == null) return null;
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
    final response = await _geminiNano.generateContent('''
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
$previousResults

Return either:
{"type":"tool_call","tool":"tool_name","arguments":{}}

or:
{"type":"final","message":"final answer"}
''');

    final action = parseSkillModelAction(response);
    if (action == null) return null;
    if (action.type == SkillModelActionType.toolCall &&
        !skill.tools.contains(action.tool)) {
      return null;
    }
    return action;
  }
}
