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
    final wantsReminder =
        lower.contains('reminder') ||
        lower.contains('notification') ||
        lower.contains('notify me') ||
        lower.contains('alert me');
    if (wantsReminder &&
        enabledSkills.any((skill) => skill.id == 'schedule-notification')) {
      return 'schedule-notification';
    }

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
    if (skill.id == 'schedule-notification') {
      return _nextScheduleNotificationAction(
        prompt: prompt,
        toolResults: toolResults,
      );
    }

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

  SkillModelAction _nextScheduleNotificationAction({
    required String prompt,
    required List<Map<String, dynamic>> toolResults,
  }) {
    final notificationResult = toolResults
        .cast<Map<String, dynamic>?>()
        .firstWhere(
          (result) => result?['tool'] == 'schedule_notification',
          orElse: () => null,
        );
    if (notificationResult != null) {
      final result =
          notificationResult['result'] as Map<String, dynamic>? ?? const {};
      final title = result['title'] as String? ?? 'reminder';
      final repeatDaily = result['repeat_daily'] as bool? ?? false;
      final hour = result['hour'] as int? ?? 9;
      final minute = result['minute'] as int? ?? 0;
      final time = _formatClockTime(hour, minute);
      if (repeatDaily && _isScheduleCheck(prompt)) {
        return SkillModelAction.finalAnswer(
          'The daily reminder to check your schedule for today has been '
          'successfully scheduled for $time.',
        );
      }
      final cadence = repeatDaily ? 'daily reminder' : 'reminder';
      return SkillModelAction.finalAnswer(
        'The $cadence "$title" has been successfully scheduled for $time.',
      );
    }

    final needsCurrentDate =
        _mentionsToday(prompt) || _mentionsTomorrow(prompt);
    final hasDateTime = toolResults.any(
      (result) => result['tool'] == 'get_current_date_time',
    );
    if (needsCurrentDate && !hasDateTime) {
      return const SkillModelAction.toolCall(tool: 'get_current_date_time');
    }

    final parsed = _parseNotificationPrompt(
      prompt: prompt,
      currentDate: _currentDateFromToolResults(toolResults),
    );
    if (parsed == null) {
      return const SkillModelAction.finalAnswer(
        'Please include a reminder time, like 9 AM or 2:30 PM.',
      );
    }

    return SkillModelAction.toolCall(
      tool: 'schedule_notification',
      arguments: parsed,
    );
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

Map<String, dynamic>? _parseNotificationPrompt({
  required String prompt,
  required String? currentDate,
}) {
  final time = _parseTime(prompt);
  if (time == null) return null;

  final repeatDaily = _isDaily(prompt);
  final scheduleCheck = _isScheduleCheck(prompt);
  final title =
      _quotedText(prompt) ??
      (scheduleCheck ? 'Daily Schedule Check' : 'Reminder');
  final message = scheduleCheck
      ? 'Check your schedule for today.'
      : 'Reminder: $title';
  final date = repeatDaily ? null : _dateFromPrompt(prompt, currentDate);

  return {
    'title': title,
    'message': message,
    'hour': time.$1,
    'minute': time.$2,
    'repeat_daily': repeatDaily,
    'date': ?date,
  };
}

(int, int)? _parseTime(String prompt) {
  final match = RegExp(
    r'(?:\bat\s+|@\s*)?(\d{1,2})(?::(\d{2}))?\s*(am|pm)?\b',
    caseSensitive: false,
  ).firstMatch(prompt);
  if (match == null) return null;

  var hour = int.tryParse(match.group(1) ?? '');
  final minute = int.tryParse(match.group(2) ?? '0') ?? 0;
  final meridiem = match.group(3)?.toLowerCase();
  if (hour == null || minute < 0 || minute > 59) return null;
  if (meridiem == 'pm' && hour < 12) hour += 12;
  if (meridiem == 'am' && hour == 12) hour = 0;
  if (hour < 0 || hour > 23) return null;
  return (hour, minute);
}

String? _dateFromPrompt(String prompt, String? currentDate) {
  if (currentDate == null) return null;
  final current = DateTime.tryParse(currentDate);
  if (current == null) return null;
  if (_mentionsTomorrow(prompt)) {
    return _formatDate(current.add(const Duration(days: 1)));
  }
  if (_mentionsToday(prompt)) return _formatDate(current);
  return null;
}

String? _currentDateFromToolResults(List<Map<String, dynamic>> toolResults) {
  final dateResult = toolResults.cast<Map<String, dynamic>?>().firstWhere(
    (result) => result?['tool'] == 'get_current_date_time',
    orElse: () => null,
  );
  final data = dateResult?['result'] as Map<String, dynamic>?;
  return data?['date'] as String?;
}

String? _quotedText(String prompt) {
  final match = RegExp(r'"([^"]+)"').firstMatch(prompt);
  return match?.group(1)?.trim();
}

bool _isDaily(String prompt) {
  final lower = prompt.toLowerCase();
  return lower.contains('daily') ||
      lower.contains('every day') ||
      lower.contains('each day');
}

bool _isScheduleCheck(String prompt) {
  final lower = prompt.toLowerCase();
  return lower.contains('check my schedule') ||
      lower.contains('check your schedule');
}

bool _mentionsToday(String prompt) => prompt.toLowerCase().contains('today');

bool _mentionsTomorrow(String prompt) {
  return prompt.toLowerCase().contains('tomorrow');
}

String _formatDate(DateTime value) {
  return '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

String _formatClockTime(int hour, int minute) {
  final period = hour >= 12 ? 'PM' : 'AM';
  final hour12 = hour % 12 == 0 ? 12 : hour % 12;
  if (minute == 0) return '$hour12:00 $period';
  return '$hour12:${minute.toString().padLeft(2, '0')} $period';
}
