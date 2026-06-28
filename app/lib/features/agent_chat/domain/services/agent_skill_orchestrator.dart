import 'dart:convert';

import '../models/agent_skill.dart';
import 'agent_connector_registry.dart';
import 'agent_skill_registry.dart';
import 'intent_parser.dart';
import 'tool_registry.dart';
import 'reminder_request_parser.dart';

enum SkillModelActionType { toolCall, finalAnswer }

class SkillModelAction {
  const SkillModelAction.toolCall({
    required this.tool,
    this.arguments = const {},
  }) : type = SkillModelActionType.toolCall,
       message = null,
       pendingCalendarEvent = null;

  const SkillModelAction.finalAnswer(this.message)
    : type = SkillModelActionType.finalAnswer,
      tool = null,
      arguments = const {},
      pendingCalendarEvent = null;

  const SkillModelAction.finalAnswerWithCalendarPrompt({
    required this.message,
    required this.pendingCalendarEvent,
  }) : type = SkillModelActionType.finalAnswer,
       tool = null,
       arguments = const {};

  final SkillModelActionType type;
  final String? tool;
  final Map<String, dynamic> arguments;
  final String? message;
  final Map<String, dynamic>? pendingCalendarEvent;
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
  static const _reminderParser = ReminderRequestParser();

  @override
  Future<String?> selectSkill({
    required String prompt,
    required List<AgentSkill> enabledSkills,
  }) async {
    if (_reminderParser.shouldSelectReminderSkill(prompt) &&
        enabledSkills.any((skill) => skill.id == 'schedule-notification')) {
      return 'schedule-notification';
    }

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
      final notifications = result['notifications'] as List? ?? const [];
      final title = result['title'] as String? ?? 'reminder';
      final firstNotification = notifications.whereType<Map>().firstOrNull;
      final category =
          result['category'] as String? ??
          firstNotification?['category'] as String? ??
          'general';
      final repeatDaily = result['repeat_daily'] as bool? ?? false;
      final requiresCompletion =
          result['requires_completion'] as bool? ??
          (result['metadata'] as Map?)?['requires_completion'] as bool? ??
          false;
      final hour = result['hour'] as int? ?? 9;
      final minute = result['minute'] as int? ?? 0;
      final time = _formatClockTime(hour, minute);
      if (notifications.length > 1) {
        final noun = category == 'medicine'
            ? 'medicine reminders'
            : 'reminders';
        return _reminderFinalAnswer(
          message: 'I scheduled ${notifications.length} $noun for "$title".',
          result: result,
          currentDate: _currentDateFromToolResults(toolResults),
        );
      }
      if (repeatDaily && _reminderParser.isScheduleCheck(prompt)) {
        return _reminderFinalAnswer(
          message:
              'The daily reminder to check your schedule for today has been '
              'successfully scheduled for $time.',
          result: result,
          currentDate: _currentDateFromToolResults(toolResults),
        );
      }
      final cadence = repeatDaily ? 'daily reminder' : 'reminder';
      if (requiresCompletion) {
        return _reminderFinalAnswer(
          message:
              'The $cadence "$title" has been scheduled for $time and will '
              'keep asking until you mark it done.',
          result: result,
          currentDate: _currentDateFromToolResults(toolResults),
        );
      }
      return _reminderFinalAnswer(
        message:
            'The $cadence "$title" has been successfully scheduled for $time.',
        result: result,
        currentDate: _currentDateFromToolResults(toolResults),
      );
    }
    final hasDateTime = toolResults.any(
      (result) => result['tool'] == 'get_current_date_time',
    );
    if (!hasDateTime) {
      return const SkillModelAction.toolCall(tool: 'get_current_date_time');
    }

    final parsed = _reminderParser.parse(
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
      arguments: parsed.toConnectorArguments(),
    );
  }

  SkillModelAction _reminderFinalAnswer({
    required String message,
    required Map<String, dynamic> result,
    required String? currentDate,
  }) {
    final pendingCalendarEvent = _calendarEventFromNotificationResult(
      result,
      currentDate: currentDate,
    );
    if (pendingCalendarEvent == null) {
      return SkillModelAction.finalAnswer(message);
    }
    return SkillModelAction.finalAnswerWithCalendarPrompt(
      message: _withCalendarPrompt(message),
      pendingCalendarEvent: pendingCalendarEvent,
    );
  }
}

class AgentSkillOrchestrator {
  AgentSkillOrchestrator({
    required AgentSkillRegistry skillRegistry,
    required AgentConnectorRegistry connectorRegistry,
    ToolRegistry? toolRegistry,
    AgentSkillModelClient? modelClient,
    bool useFallbackModelClient = true,
    int maxSteps = 4,
    Duration modelActionTimeout = const Duration(seconds: 3),
  }) : _skillRegistry = skillRegistry,
       _connectorRegistry = connectorRegistry,
       _toolRegistry = toolRegistry ?? ToolRegistry(),
       _modelClient = modelClient ?? RuleBasedAgentSkillModelClient(),
       _fallbackModelClient = useFallbackModelClient
           ? RuleBasedAgentSkillModelClient()
           : null,
       _maxSteps = maxSteps,
       _modelActionTimeout = modelActionTimeout;

  final AgentSkillRegistry _skillRegistry;
  final AgentConnectorRegistry _connectorRegistry;
  final ToolRegistry _toolRegistry;
  final AgentSkillModelClient _modelClient;
  final RuleBasedAgentSkillModelClient? _fallbackModelClient;
  final int _maxSteps;
  final Duration _modelActionTimeout;

  String buildSkillSelectionPrompt(String userPrompt) {
    final summaries = _skillRegistry.enabledSkillSummariesForPrompt();
    return [
      'Choose one Airo Agent Skill for the user request, or choose no skill.',
      'Return JSON only: {"skill_id":"skill-id"} or {"skill_id":null}.',
      'Available enabled skills:',
      if (summaries.isEmpty) '- none' else ...summaries,
      'User request: $userPrompt',
    ].join('\n');
  }

  Future<AgentRunResult> run(String prompt) async {
    final enabledSkills = _skillRegistry.getEnabledSkills();
    final selectedSkillId =
        await _tryModelCall(
          () => _modelClient.selectSkill(
            prompt: prompt,
            enabledSkills: enabledSkills,
          ),
        ) ??
        await _fallbackModelClient?.selectSkill(
          prompt: prompt,
          enabledSkills: enabledSkills,
        );

    if (selectedSkillId == null) {
      return _fallbackToRouteIntent(prompt);
    }

    final skill = _skillRegistry.getById(selectedSkillId);
    if (skill == null || !skill.enabled) {
      return const AgentRunResult.notHandled();
    }

    final traces = [AgentActionTrace(title: 'Load skill', detail: skill.id)];
    final toolResults = <Map<String, dynamic>>[];

    for (var step = 0; step < _maxSteps; step++) {
      final action =
          await _tryModelCall(
            () => _modelClient.nextAction(
              prompt: prompt,
              skill: skill,
              toolResults: toolResults,
            ),
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
          pendingCalendarEvent: action.pendingCalendarEvent,
        );
      }

      final tool = _normalizeToolName(action.tool, skill);
      if (tool == null || !skill.tools.contains(tool)) {
        traces.add(
          AgentActionTrace(
            title: 'Blocked action',
            detail: action.tool ?? 'unknown',
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

      final actionStopwatch = Stopwatch()..start();
      final result = await _connectorRegistry.execute(tool, action.arguments);
      actionStopwatch.stop();
      traces.add(
        AgentActionTrace(
          title: 'Execute action',
          detail: tool,
          parameters: action.arguments,
          success: !result.isError,
          durationMs: actionStopwatch.elapsedMilliseconds,
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

      if (tool == 'open_route') {
        final route = result.data['route'] as String?;
        return AgentRunResult(
          handled: true,
          message: result.data['message'] as String? ?? 'Opening Airo feature.',
          traces: traces,
          route: route,
          parameters:
              (result.data['parameters'] as Map?)?.cast<String, dynamic>() ??
              const {},
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

  Future<AgentRunResult> _fallbackToRouteIntent(String prompt) async {
    final intent = IntentParser.parse(prompt);
    if (!_isSimpleRouteIntent(intent.type)) {
      return const AgentRunResult.notHandled();
    }
    final result = await _toolRegistry.executeIntent(intent);
    if (!result.shouldNavigate) return const AgentRunResult.notHandled();
    return AgentRunResult(
      handled: true,
      message: result.message,
      traces: [
        AgentActionTrace(
          title: 'Fallback intent',
          detail: IntentParser.describe(intent),
          parameters: result.parameters,
        ),
      ],
      isError: result.isError,
    );
  }

  bool _isSimpleRouteIntent(IntentType type) {
    return type == IntentType.openMoney ||
        type == IntentType.openBudget ||
        type == IntentType.openExpenses ||
        type == IntentType.playMusic ||
        type == IntentType.pauseMusic ||
        type == IntentType.nextTrack ||
        type == IntentType.playGames ||
        type == IntentType.playChess ||
        type == IntentType.playGame ||
        type == IntentType.openOffers ||
        type == IntentType.openReader ||
        type == IntentType.openChat ||
        type == IntentType.askImage ||
        type == IntentType.modelManagement;
  }

  Future<T?> _tryModelCall<T>(Future<T?> Function() call) async {
    try {
      return await call().timeout(_modelActionTimeout);
    } catch (_) {
      return null;
    }
  }
}

String? _normalizeToolName(String? tool, AgentSkill skill) {
  if (tool == null) return null;
  if (skill.tools.contains(tool)) return tool;

  final normalized = tool
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  if (skill.tools.contains(normalized)) return normalized;

  if (normalized == 'open_root' && skill.tools.contains('open_route')) {
    return 'open_route';
  }

  return tool;
}

String _withCalendarPrompt(String message) {
  return '$message Do you want me to add this to your calendar too so it can '
      'sync across devices?';
}

Map<String, dynamic>? _calendarEventFromNotificationResult(
  Map<String, dynamic> result, {
  required String? currentDate,
}) {
  final notifications = result['notifications'] as List? ?? const [];
  if (notifications.length > 1) return null;

  final notification = notifications.whereType<Map>().firstOrNull ?? result;
  final title = notification['title'] as String? ?? result['title'] as String?;
  final date =
      notification['date'] as String? ??
      result['date'] as String? ??
      currentDate;
  final hour = notification['hour'] as int? ?? result['hour'] as int?;
  final minute =
      notification['minute'] as int? ?? result['minute'] as int? ?? 0;
  if (title == null || title.isEmpty || date == null || hour == null) {
    return null;
  }

  return {
    'title': title,
    'message':
        notification['message'] as String? ??
        result['message'] as String? ??
        'Reminder: $title',
    'date': date,
    'hour': hour,
    'minute': minute,
    'duration_minutes': 30,
    'repeat_daily':
        notification['repeat_daily'] as bool? ??
        result['repeat_daily'] as bool? ??
        false,
    'source': 'reminder_confirmation',
  };
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

String? _currentDateFromToolResults(List<Map<String, dynamic>> toolResults) {
  final dateResult = toolResults.cast<Map<String, dynamic>?>().firstWhere(
    (result) => result?['tool'] == 'get_current_date_time',
    orElse: () => null,
  );
  final data = dateResult?['result'] as Map<String, dynamic>?;
  return data?['date'] as String?;
}

String _formatClockTime(int hour, int minute) {
  final period = hour >= 12 ? 'PM' : 'AM';
  final hour12 = hour % 12 == 0 ? 12 : hour % 12;
  if (minute == 0) return '$hour12:00 $period';
  return '$hour12:${minute.toString().padLeft(2, '0')} $period';
}
