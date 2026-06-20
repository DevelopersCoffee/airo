import 'dart:convert';

import '../models/agent_skill.dart';
import 'agent_connector_registry.dart';
import 'agent_skill_registry.dart';

enum SkillModelActionType { toolCall, finalAnswer }

class SkillModelAction {
  const SkillModelAction.toolCall({
    required this.tool,
    this.arguments = const {},
  }) : type = SkillModelActionType.toolCall,
       message = null;

  const SkillModelAction.finalAnswer(this.message)
    : type = SkillModelActionType.finalAnswer,
      tool = null,
      arguments = const {};

  final SkillModelActionType type;
  final String? tool;
  final Map<String, dynamic> arguments;
  final String? message;
}

abstract interface class AgentSkillModelClient {
  Future<String?> selectSkill({
    required String prompt,
    required List<AgentSkill> enabledSkills,
  });

  Future<SkillModelAction?> nextAction({
    required String prompt,
    required AgentSkill skill,
    required List<Map<String, dynamic>> toolResults,
  });
}

class RuleBasedAgentSkillModelClient implements AgentSkillModelClient {
  @override
  Future<String?> selectSkill({
    required String prompt,
    required List<AgentSkill> enabledSkills,
  }) async {
    final lower = prompt.toLowerCase();
    final wantsCalendar =
        lower.contains('calendar') ||
        lower.contains('meeting') ||
        lower.contains('agenda') ||
        lower.contains('appointment') ||
        (lower.contains('schedule') &&
            (lower.contains('check') ||
                lower.contains('show') ||
                lower.contains('what') ||
                lower.contains('today') ||
                lower.contains('tomorrow')));
    if (!wantsCalendar) return null;
    if (enabledSkills.any((skill) => skill.id == 'read-calendar-events')) {
      return 'read-calendar-events';
    }
    return null;
  }

  @override
  Future<SkillModelAction?> nextAction({
    required String prompt,
    required AgentSkill skill,
    required List<Map<String, dynamic>> toolResults,
  }) async {
    if (skill.id != 'read-calendar-events') return null;

    final hasDateTime = toolResults.any(
      (result) => result['tool'] == 'get_current_date_time',
    );
    final calendarResult = toolResults.cast<Map<String, dynamic>?>().firstWhere(
      (result) => result?['tool'] == 'read_calendar_events',
      orElse: () => null,
    );

    if (!hasDateTime) {
      return const SkillModelAction.toolCall(tool: 'get_current_date_time');
    }

    if (calendarResult == null) {
      final dateResult = toolResults.firstWhere(
        (result) => result['tool'] == 'get_current_date_time',
      );
      final data = dateResult['result'] as Map<String, dynamic>? ?? const {};
      return SkillModelAction.toolCall(
        tool: 'read_calendar_events',
        arguments: {'date': data['date']},
      );
    }

    final result =
        calendarResult['result'] as Map<String, dynamic>? ?? const {};
    final events = result['events'] as List? ?? const [];
    if (events.isEmpty) {
      return const SkillModelAction.finalAnswer(
        'I checked your schedule, and there are no events scheduled for today.',
      );
    }

    final lines = events
        .map((event) {
          final item = event as Map;
          return '${_formatEventTime(item['start'])} ${item['title']}';
        })
        .join('\n');
    return SkillModelAction.finalAnswer('Here is your schedule:\n$lines');
  }
}

class AgentSkillOrchestrator {
  AgentSkillOrchestrator({
    required AgentSkillRegistry skillRegistry,
    required AgentConnectorRegistry connectorRegistry,
    AgentSkillModelClient? modelClient,
    bool useFallbackModelClient = true,
    int maxSteps = 4,
  }) : _skillRegistry = skillRegistry,
       _connectorRegistry = connectorRegistry,
       _modelClient = modelClient ?? RuleBasedAgentSkillModelClient(),
       _fallbackModelClient = useFallbackModelClient
           ? RuleBasedAgentSkillModelClient()
           : null,
       _maxSteps = maxSteps;

  final AgentSkillRegistry _skillRegistry;
  final AgentConnectorRegistry _connectorRegistry;
  final AgentSkillModelClient _modelClient;
  final RuleBasedAgentSkillModelClient? _fallbackModelClient;
  final int _maxSteps;

  Future<AgentRunResult> run(String prompt) async {
    final enabledSkills = _skillRegistry.getEnabledSkills();
    final selectedSkillId =
        await _modelClient.selectSkill(
          prompt: prompt,
          enabledSkills: enabledSkills,
        ) ??
        await _fallbackModelClient?.selectSkill(
          prompt: prompt,
          enabledSkills: enabledSkills,
        );

    if (selectedSkillId == null) {
      return const AgentRunResult.notHandled();
    }

    final skill = _skillRegistry.getById(selectedSkillId);
    if (skill == null || !skill.enabled) {
      return const AgentRunResult.notHandled();
    }

    final traces = [AgentActionTrace(title: 'Load skill', detail: skill.id)];
    final toolResults = <Map<String, dynamic>>[];

    for (var step = 0; step < _maxSteps; step++) {
      final action =
          await _modelClient.nextAction(
            prompt: prompt,
            skill: skill,
            toolResults: toolResults,
          ) ??
          await _fallbackModelClient?.nextAction(
            prompt: prompt,
            skill: skill,
            toolResults: toolResults,
          );

      if (action == null) {
        return AgentRunResult(
          handled: true,
          message: 'I could not complete that skill.',
          traces: traces,
          isError: true,
        );
      }

      if (action.type == SkillModelActionType.finalAnswer) {
        return AgentRunResult(
          handled: true,
          message: action.message ?? '',
          traces: traces,
        );
      }

      final tool = action.tool;
      if (tool == null || !skill.tools.contains(tool)) {
        traces.add(
          AgentActionTrace(
            title: 'Blocked action',
            detail: tool ?? 'unknown',
            success: false,
          ),
        );
        return AgentRunResult(
          handled: true,
          message: 'That skill tried to use an unsupported action.',
          traces: traces,
          isError: true,
        );
      }

      final connector = _connectorRegistry.getConnector(tool);
      if (connector == null) {
        traces.add(
          AgentActionTrace(
            title: 'Missing connector',
            detail: tool,
            success: false,
          ),
        );
        return AgentRunResult(
          handled: true,
          message: 'That action is not available on this device yet.',
          traces: traces,
          isError: true,
        );
      }

      final missingCapabilities = connector.requiredCapabilities
          .where((capability) => !skill.capabilities.contains(capability))
          .toList();
      if (missingCapabilities.isNotEmpty) {
        traces.add(
          AgentActionTrace(
            title: 'Blocked capability',
            detail: missingCapabilities.first.key,
            success: false,
          ),
        );
        return AgentRunResult(
          handled: true,
          message: 'That skill does not have permission to use this action.',
          traces: traces,
          isError: true,
        );
      }

      final result = await _connectorRegistry.execute(tool, action.arguments);
      traces.add(
        AgentActionTrace(
          title: 'Execute action',
          detail: tool,
          parameters: action.arguments,
          success: !result.isError,
        ),
      );
      toolResults.add({
        'tool': tool,
        'arguments': action.arguments,
        'result': result.data,
        if (result.isError) 'error': result.errorCode,
      });

      if (result.isError) {
        return AgentRunResult(
          handled: true,
          message: result.message ?? 'The action failed.',
          traces: traces,
          isError: true,
        );
      }
    }

    return AgentRunResult(
      handled: true,
      message: 'The skill took too many steps and was stopped.',
      traces: traces,
      isError: true,
    );
  }
}

SkillModelAction? parseSkillModelAction(String text) {
  try {
    final decoded = jsonDecode(_stripCodeFence(text));
    if (decoded is! Map<String, dynamic>) return null;
    final type = decoded['type'] as String?;
    if (type == 'final') {
      return SkillModelAction.finalAnswer(decoded['message'] as String? ?? '');
    }
    if (type == 'tool_call') {
      return SkillModelAction.toolCall(
        tool: decoded['tool'] as String? ?? '',
        arguments:
            (decoded['arguments'] as Map?)?.cast<String, dynamic>() ?? const {},
      );
    }
  } catch (_) {
    return null;
  }
  return null;
}

String? parseSelectedSkillId(String text) {
  try {
    final decoded = jsonDecode(_stripCodeFence(text));
    if (decoded is! Map<String, dynamic>) return null;
    return decoded['skill_id'] as String?;
  } catch (_) {
    return null;
  }
}

String _stripCodeFence(String text) {
  final trimmed = text.trim();
  final match = RegExp(
    r'```(?:json)?\s*([\s\S]*?)\s*```',
    multiLine: true,
  ).firstMatch(trimmed);
  return match?.group(1)?.trim() ?? trimmed;
}

String _formatEventTime(dynamic value) {
  final text = value?.toString() ?? '';
  if (text.length >= 16) return text.substring(11, 16);
  return text;
}
