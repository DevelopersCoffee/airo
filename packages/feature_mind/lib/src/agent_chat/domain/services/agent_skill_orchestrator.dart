import 'dart:convert';

import 'package:core_ai/core_ai.dart';

import '../../../addons/addon_trace_redaction.dart';
import '../../../addons/workflow/addon_workflow_fact_service.dart';
import '../../../runtime/models/capability_models.dart';
import '../../../runtime/models/log_models.dart';
import '../../../runtime/ports/operation_log_port.dart';
import '../models/agent_skill.dart';
import '../models/data_volume_measurement.dart';
import '../models/grounded_citation.dart';
import 'agent_connector_registry.dart';
import 'agent_skill_registry.dart';
import 'capability_safety_resolver.dart';
import 'chat_entity_graph_pending.dart';
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
       pendingCalendarEvent = null,
       pendingCalendarPermission = false,
       pendingLifeTrackWrite = null,
       schemaInvalid = false;

  const SkillModelAction.finalAnswer(this.message, {this.schemaInvalid = false})
    : type = SkillModelActionType.finalAnswer,
      tool = null,
      arguments = const {},
      pendingCalendarEvent = null,
      pendingCalendarPermission = false,
      pendingLifeTrackWrite = null;

  const SkillModelAction.finalAnswerWithCalendarPrompt({
    required this.message,
    required this.pendingCalendarEvent,
  }) : type = SkillModelActionType.finalAnswer,
       tool = null,
       arguments = const {},
       pendingCalendarPermission = false,
       pendingLifeTrackWrite = null,
       schemaInvalid = false;

  const SkillModelAction.finalAnswerWithCalendarPermission({
    required this.message,
  }) : type = SkillModelActionType.finalAnswer,
       tool = null,
       arguments = const {},
       pendingCalendarEvent = null,
       pendingCalendarPermission = true,
       pendingLifeTrackWrite = null,
       schemaInvalid = false;

  const SkillModelAction.finalAnswerWithLifeTrackWrite({
    required this.message,
    required this.pendingLifeTrackWrite,
  }) : type = SkillModelActionType.finalAnswer,
       tool = null,
       arguments = const {},
       pendingCalendarEvent = null,
       pendingCalendarPermission = false,
       schemaInvalid = false;

  final SkillModelActionType type;
  final String? tool;
  final Map<String, dynamic> arguments;
  final String? message;
  final Map<String, dynamic>? pendingCalendarEvent;
  final bool pendingCalendarPermission;
  final Map<String, dynamic>? pendingLifeTrackWrite;
  final bool schemaInvalid;
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
  RuleBasedAgentSkillModelClient({
    AddonWorkflowFactService? factService,
    ChatEntityGraphPending? graphPending,
  }) : _factService = factService ?? AddonWorkflowFactService(),
       _graphPending = graphPending ?? ChatEntityGraphPending();

  static const _reminderParser = ReminderRequestParser();
  final AddonWorkflowFactService _factService;
  final ChatEntityGraphPending _graphPending;

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
    if (_wantsWellbeing(lower) &&
        enabledSkills.any((skill) => skill.id == 'wellbeing-check-in')) {
      return 'wellbeing-check-in';
    }
    if (_factService.facts.wantsStudyRecord(prompt) &&
        enabledSkills.any((skill) => skill.id == 'record-study-progress')) {
      return 'record-study-progress';
    }
    if (_wantsLifeTrackStatus(lower) &&
        enabledSkills.any((skill) => skill.id == 'query-lifetrack-status')) {
      return 'query-lifetrack-status';
    }

    if (!promptWantsCalendarRead(prompt)) return null;
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

    if (skill.id == 'query-lifetrack-status') {
      return _nextLifeTrackStatusAction(
        prompt: prompt,
        toolResults: toolResults,
      );
    }

    if (skill.id == 'wellbeing-check-in') {
      return _nextWellbeingAction(prompt: prompt, toolResults: toolResults);
    }

    final lower = prompt.toLowerCase();
    final templateId = skill.lifeTrackTemplateId;
    if (templateId != null &&
        _factService.wantsRecord(
      AgentSkillRecordContext(
        skillId: skill.id,
        skillTools: skill.tools,
        templateId: templateId,
        prompt: prompt,
      ),
    )) {
      return _nextRecordLifeTrackAction(
        prompt: prompt,
        toolResults: toolResults,
        templateId: templateId,
      );
    }
    if (skill.tools.contains('query_entity_graph') &&
        _graphPending.wantsPending(prompt)) {
      return _nextClaimPendingAction(
        prompt: prompt,
        skill: skill,
        toolResults: toolResults,
      );
    }
    if (skill.tools.contains('query_entity_graph') &&
        _wantsEntityGraph(lower)) {
      return _nextEntityGraphAction(prompt: prompt, toolResults: toolResults);
    }
    if (skill.tools.contains('query_lifetrack_status') &&
        (skill.id == 'query-lifetrack-status' ||
            _wantsLifeTrackStatus(lower))) {
      return _nextLifeTrackStatusAction(
        prompt: prompt,
        toolResults: toolResults,
      );
    }

    if (skill.tools.contains('schedule_notification') &&
        skill.id != 'schedule-notification' &&
        _reminderParser.shouldSelectReminderSkill(prompt)) {
      return _nextScheduleNotificationAction(
        prompt: prompt,
        toolResults: toolResults,
      );
    }

    if (!skill.tools.contains('read_calendar_events')) return null;
    if (skill.id != 'read-calendar-events' &&
        !promptWantsCalendarRead(prompt)) {
      return null;
    }

    final permissionResult = toolResults
        .cast<Map<String, dynamic>?>()
        .firstWhere(
          (result) => result?['tool'] == 'calendar_permission_status',
          orElse: () => null,
        );
    if (permissionResult == null &&
        skill.tools.contains('calendar_permission_status')) {
      return const SkillModelAction.toolCall(
        tool: 'calendar_permission_status',
      );
    }
    if (permissionResult != null) {
      final data =
          permissionResult['result'] as Map<String, dynamic>? ?? const {};
      final status = data['status'] as String? ?? '';
      final granted = data['granted'] == true;
      if (status == 'unsupported' ||
          permissionResult['error'] == 'PLATFORM_UNSUPPORTED') {
        return const SkillModelAction.finalAnswer(
          "Calendar access isn't supported on this device yet.",
        );
      }
      if (!granted &&
          (status == 'notDetermined' || status == 'not_determined')) {
        return const SkillModelAction.finalAnswerWithCalendarPermission(
          message: 'Airo needs calendar access to read your events.',
        );
      }
      if (!granted) {
        return const SkillModelAction.finalAnswer(
          'Calendar access is disabled. Enable it in system settings to let Airo read your calendar.',
        );
      }
    }

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
      final today = data['date'] as String? ?? '';
      return SkillModelAction.toolCall(
        tool: 'read_calendar_events',
        arguments: _calendarQueryArguments(
          prompt,
          today,
          currentTime: data['time'] as String?,
        ),
      );
    }

    final result =
        calendarResult['result'] as Map<String, dynamic>? ?? const {};
    if (result['source'] == 'calendar_channel_unavailable' ||
        calendarResult['error'] == 'calendar_channel_unavailable') {
      return const SkillModelAction.finalAnswer(
        'Calendar events are not available on this device yet.',
      );
    }
    final events = result['events'] as List? ?? const [];
    if (events.isEmpty) {
      return SkillModelAction.finalAnswer(_emptyCalendarMessage(prompt));
    }

    return SkillModelAction.finalAnswer(_summarizeCalendarEvents(events));
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

  SkillModelAction _nextLifeTrackStatusAction({
    required String prompt,
    required List<Map<String, dynamic>> toolResults,
  }) {
    final statusResult = toolResults.cast<Map<String, dynamic>?>().firstWhere(
      (result) => result?['tool'] == 'query_lifetrack_status',
      orElse: () => null,
    );
    if (statusResult == null) {
      return SkillModelAction.toolCall(
        tool: 'query_lifetrack_status',
        arguments: {'query': prompt},
      );
    }

    final result = statusResult['result'] as Map<String, dynamic>? ?? const {};
    return SkillModelAction.finalAnswer(
      result['markdown'] as String? ??
          'I could not read LifeTrack status from local data.',
    );
  }

  SkillModelAction _nextRecordLifeTrackAction({
    required String prompt,
    required List<Map<String, dynamic>> toolResults,
    required String templateId,
  }) {
    final recordResult = toolResults.cast<Map<String, dynamic>?>().firstWhere(
      (result) => result?['tool'] == 'record_lifetrack_facts',
      orElse: () => null,
    );
    if (recordResult != null) {
      final result =
          recordResult['result'] as Map<String, dynamic>? ?? const {};
      return SkillModelAction.finalAnswer(
        result['markdown'] as String? ??
            'I stored that journey in local LifeTrack.',
      );
    }

    final extracted = _factService.extract(templateId, prompt);
    if (extracted.isEmpty) {
      return SkillModelAction.finalAnswer(
        _factService.clarificationHint(templateId),
      );
    }

    return SkillModelAction.toolCall(
      tool: 'record_lifetrack_facts',
      arguments: {
        'title': extracted.title,
        'template_id': templateId,
        'facts': extracted.facts,
      },
    );
  }

  bool _wantsLifeTrackStatus(String lowerPrompt) {
    final mentionsLifeTrack =
        lowerPrompt.contains('lifetrack') ||
        lowerPrompt.contains('life track') ||
        lowerPrompt.contains('track') ||
        lowerPrompt.contains('goal');
    final asksStatus =
        lowerPrompt.contains('pending') ||
        lowerPrompt.contains('status') ||
        lowerPrompt.contains('progress') ||
        lowerPrompt.contains('document') ||
        lowerPrompt.contains('documents') ||
        lowerPrompt.contains('need');
    return mentionsLifeTrack && asksStatus;
  }

  bool _wantsEntityGraph(String lowerPrompt) {
    return lowerPrompt.contains('related') ||
        lowerPrompt.contains('linked') ||
        lowerPrompt.contains('entity') ||
        lowerPrompt.contains('who is') ||
        lowerPrompt.contains('which insurer') ||
        lowerPrompt.contains('which broker') ||
        lowerPrompt.contains('what do you know') ||
        lowerPrompt.contains('remember about');
  }

  SkillModelAction _nextEntityGraphAction({
    required String prompt,
    required List<Map<String, dynamic>> toolResults,
  }) {
    final graphResult = toolResults.cast<Map<String, dynamic>?>().firstWhere(
      (result) => result?['tool'] == 'query_entity_graph',
      orElse: () => null,
    );
    if (graphResult == null) {
      return SkillModelAction.toolCall(
        tool: 'query_entity_graph',
        arguments: {'query': prompt},
      );
    }
    final result = graphResult['result'] as Map<String, dynamic>? ?? const {};
    return SkillModelAction.finalAnswer(
      result['markdown'] as String? ?? 'I could not read stored chat entities.',
    );
  }

  SkillModelAction _nextClaimPendingAction({
    required String prompt,
    required AgentSkill skill,
    required List<Map<String, dynamic>> toolResults,
  }) {
    final graphResult = toolResults.cast<Map<String, dynamic>?>().firstWhere(
      (result) => result?['tool'] == 'query_entity_graph',
      orElse: () => null,
    );
    if (graphResult == null) {
      return SkillModelAction.toolCall(
        tool: 'query_entity_graph',
        arguments: {'query': prompt, 'intent': 'pending'},
      );
    }

    if (skill.tools.contains('query_lifetrack_status')) {
      final statusResult = toolResults.cast<Map<String, dynamic>?>().firstWhere(
        (result) => result?['tool'] == 'query_lifetrack_status',
        orElse: () => null,
      );
      if (statusResult == null) {
        return SkillModelAction.toolCall(
          tool: 'query_lifetrack_status',
          arguments: {'query': prompt},
        );
      }
      return SkillModelAction.finalAnswer(
        _combinePendingAnswers(
          graphMarkdown:
              (graphResult['result'] as Map<String, dynamic>?)?['markdown']
                  as String?,
          lifeTrackMarkdown:
              (statusResult['result'] as Map<String, dynamic>?)?['markdown']
                  as String?,
        ),
      );
    }

    final result = graphResult['result'] as Map<String, dynamic>? ?? const {};
    return SkillModelAction.finalAnswer(
      result['markdown'] as String? ?? 'I could not read stored chat entities.',
    );
  }

  String _combinePendingAnswers({
    required String? graphMarkdown,
    required String? lifeTrackMarkdown,
  }) {
    final graph = graphMarkdown?.trim() ?? '';
    final lifeTrack = lifeTrackMarkdown?.trim() ?? '';
    final graphUseful =
        graph.isNotEmpty &&
        !graph.contains('no stored claim entities') &&
        !graph.contains('no stored chat entities') &&
        !graph.contains('no stored hospital') &&
        !graph.contains('no stored property');
    final lifeTrackUseful =
        lifeTrack.isNotEmpty &&
        !lifeTrack.contains('I could not find a LifeTrack matching');
    if (graphUseful && lifeTrackUseful) {
      return '$graph\n\nLifeTrack\n\n$lifeTrack';
    }
    if (lifeTrackUseful) return lifeTrack;
    if (graphUseful) return graph;
    if (lifeTrack.isNotEmpty) return lifeTrack;
    if (graph.isNotEmpty) return graph;
    return 'I have no stored claim data yet.';
  }

  SkillModelAction _nextWellbeingAction({
    required String prompt,
    required List<Map<String, dynamic>> toolResults,
  }) {
    final lower = prompt.toLowerCase();
    final wantsBreathing =
        lower.contains('breath') ||
        lower.contains('calm') ||
        lower.contains('anxious') ||
        lower.contains('anxiety');
    final tool = wantsBreathing ? 'guide_breathing' : 'log_reflection';
    final existing = toolResults.cast<Map<String, dynamic>?>().firstWhere(
      (result) => result?['tool'] == tool,
      orElse: () => null,
    );
    if (existing == null) {
      return SkillModelAction.toolCall(
        tool: tool,
        arguments: wantsBreathing ? const {} : {'note': prompt.trim()},
      );
    }
    final result = existing['result'] as Map<String, dynamic>? ?? const {};
    final message = existing['message'] as String?;
    if (tool == 'guide_breathing') {
      final steps = (result['steps'] as List?)?.join('\n- ') ?? '';
      return SkillModelAction.finalAnswer(
        'Here is a ${result['duration_seconds'] ?? 60}-second box breathing '
        'reset:\n- $steps',
      );
    }
    return SkillModelAction.finalAnswer(
      message ??
          (result['prompt'] as String? ?? 'What felt heavy or light today?'),
    );
  }

  bool _wantsWellbeing(String lowerPrompt) {
    const markers = [
      'wellbeing',
      'well-being',
      'breathing',
      'breathe',
      'breath',
      'check-in',
      'check in',
      'reflection',
      'reflect',
      'daily insight',
      'calm down',
      'anxious',
      'anxiety',
      'how am i feeling',
    ];
    return markers.any(lowerPrompt.contains);
  }
}

bool promptWantsCalendarRead(String prompt) {
  final lower = prompt.toLowerCase();
  if (lower.contains('calendar') ||
      lower.contains('meeting') ||
      lower.contains('agenda') ||
      lower.contains('appointment')) {
    return true;
  }
  if (lower.contains('schedule') &&
      (lower.contains('check') ||
          lower.contains('show') ||
          lower.contains('what') ||
          lower.contains('today') ||
          lower.contains('tomorrow') ||
          lower.contains('list'))) {
    return true;
  }
  if (lower.contains('event') &&
      (lower.contains('list') ||
          lower.contains('show') ||
          lower.contains('all') ||
          lower.contains('my') ||
          lower.contains('today') ||
          lower.contains('tomorrow'))) {
    return true;
  }
  return false;
}

class AgentSkillOrchestrator {
  AgentSkillOrchestrator({
    required this._skillRegistry,
    required this._connectorRegistry,
    ToolRegistry? toolRegistry,
    AgentSkillModelClient? modelClient,
    bool useFallbackModelClient = true,
    bool preferDeterministicSkills = false,
    this._maxSteps = 6,
    this._modelActionTimeout = const Duration(seconds: 3),
    this._operationLogPort,
  }) : _toolRegistry = toolRegistry ?? ToolRegistry(),
       _modelClient = modelClient ?? RuleBasedAgentSkillModelClient(),
       _fallbackModelClient = useFallbackModelClient
           ? RuleBasedAgentSkillModelClient()
           : null,
       _preferDeterministicSkills = preferDeterministicSkills;

  final AgentSkillRegistry _skillRegistry;
  final AgentConnectorRegistry _connectorRegistry;
  final ToolRegistry _toolRegistry;
  final AgentSkillModelClient _modelClient;
  final RuleBasedAgentSkillModelClient? _fallbackModelClient;
  final bool _preferDeterministicSkills;
  final int _maxSteps;
  final Duration _modelActionTimeout;

  /// Grounds a skill's final answer in a real logged operation. Null in any
  /// context that has not wired the log yet — every answer that context
  /// produces surfaces as [GroundingState.ungrounded], never as a silent,
  /// unbacked "grounded" claim.
  final OperationLogPort? _operationLogPort;

  String buildSkillSelectionPrompt(String userPrompt) {
    final summaries = _skillRegistry.enabledSkillSummariesForPrompt();
    return [
      'Choose one Airo Agent Skill for the user request, or choose no skill.',
      'Return JSON only: {"skill_id":"skill-id"} or {"skill_id":null}.',
      'If the best match is a plugin for the chat model, return {"skill_id":null}.',
      'Available enabled skills:',
      if (summaries.isEmpty) '- none' else ...summaries,
      'User request: $userPrompt',
    ].join('\n');
  }

  Future<AgentRunResult> run(String prompt, {String? pinnedPersonaId}) async {
    final pinned = pinnedPersonaId == null
        ? null
        : _skillRegistry.getById(pinnedPersonaId);
    if (pinned != null && pinned.isPersona) {
      if (pinned.isGenerativePlugin) {
        return const AgentRunResult.notHandled();
      }
      return _runSelectedSkill(prompt, pinned);
    }

    // Diet/meal plans are a generative plugin. Compact local routers often
    // mis-select `read-calendar-events` for "7 day plan" and then ask for
    // calendar permission instead of writing meals.
    if (IntentParser.parse(prompt).type == IntentType.createDietPlan) {
      return const AgentRunResult.notHandled();
    }

    final enabledSkills = _skillRegistry
        .getEnabledSkills()
        .where((skill) => !skill.isPersona)
        .toList(growable: false);
    var selectedSkillId = _preferDeterministicSkills
        ? await _fallbackModelClient?.selectSkill(
                prompt: prompt,
                enabledSkills: enabledSkills,
              ) ??
              await _tryModelCall(
                () => _modelClient.selectSkill(
                  prompt: prompt,
                  enabledSkills: enabledSkills,
                ),
              )
        : await _tryModelCall(
                () => _modelClient.selectSkill(
                  prompt: prompt,
                  enabledSkills: enabledSkills,
                ),
              ) ??
              await _fallbackModelClient?.selectSkill(
                prompt: prompt,
                enabledSkills: enabledSkills,
              );

    if (selectedSkillId == 'read-calendar-events' &&
        !promptWantsCalendarRead(prompt)) {
      selectedSkillId = null;
    }

    if (selectedSkillId == null) {
      return _fallbackToRouteIntent(prompt);
    }

    final skill = _skillRegistry.getById(selectedSkillId);
    if (skill == null || !skill.enabled) {
      return const AgentRunResult.notHandled();
    }
    if (skill.isGenerativePlugin) {
      return const AgentRunResult.notHandled();
    }

    return _runSelectedSkill(prompt, skill);
  }

  Future<AgentRunResult> _runSelectedSkill(
    String prompt,
    AgentSkill skill,
  ) async {
    final traces = [AgentActionTrace(title: 'Load skill', detail: skill.id)];
    final toolResults = <Map<String, dynamic>>[];
    final safetyClass = skill.isPersona
        ? (skill.safetyClass == CapabilitySafetyClass.general
              ? null
              : skill.safetyClass)
        : resolveCapabilitySafetyClass(
            skill.capabilities,
            declared: skill.safetyClass,
          );
    GroundedCitation? latestCitation;

    for (var step = 0; step < _maxSteps; step++) {
      SkillModelAction? action;
      final fallback = _fallbackModelClient;
      if (_preferDeterministicSkills &&
          skill.id == 'read-calendar-events' &&
          fallback != null) {
        action = await fallback.nextAction(
          prompt: prompt,
          skill: skill,
          toolResults: toolResults,
        );
      } else {
        action =
            await _tryModelCall(
              () => _modelClient.nextAction(
                prompt: prompt,
                skill: skill,
                toolResults: toolResults,
              ),
            ) ??
            await fallback?.nextAction(
              prompt: prompt,
              skill: skill,
              toolResults: toolResults,
            );
        if (action?.type == SkillModelActionType.finalAnswer &&
            skill.id == 'read-calendar-events' &&
            fallback != null) {
          action = await fallback.nextAction(
            prompt: prompt,
            skill: skill,
            toolResults: toolResults,
          );
        }
      }

      if (action == null) {
        return const AgentRunResult.notHandled();
      }

      if (action.type == SkillModelActionType.finalAnswer) {
        if (action.schemaInvalid) {
          traces.add(
            const AgentActionTrace(
              title: 'Blocked schema violation',
              detail: 'AIRO-R04',
              success: false,
            ),
          );
          return AgentRunResult(
            handled: true,
            message: action.message ?? OutputSchemaGuard.userMessage(),
            traces: traces,
            isError: true,
            safetyClass: safetyClass,
          );
        }
        final executedTools = traces
            .where((trace) => trace.success && trace.title == 'Execute action')
            .map((trace) => trace.detail);
        final denied = ToolAuthorityGuard.denyUngroundedClaim(
          message: action.message ?? '',
          executedTools: executedTools,
        );
        if (denied != null) {
          traces.add(
            const AgentActionTrace(
              title: 'Blocked ungrounded tool claim',
              detail: 'AIRO-R03',
              success: false,
            ),
          );
          return AgentRunResult(
            handled: true,
            message: denied,
            traces: traces,
            isError: true,
            safetyClass: safetyClass,
          );
        }
        return AgentRunResult(
          handled: true,
          message: action.message ?? '',
          traces: traces,
          pendingCalendarEvent: action.pendingCalendarEvent,
          pendingCalendarPermission: action.pendingCalendarPermission,
          pendingLifeTrackWrite: action.pendingLifeTrackWrite,
          citations: latestCitation == null ? const [] : [latestCitation],
          groundingState: latestCitation == null
              ? GroundingState.ungrounded
              : GroundingState.grounded,
          safetyClass: safetyClass,
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
          safetyClass: safetyClass,
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
          safetyClass: safetyClass,
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
          safetyClass: safetyClass,
        );
      }

      final actionStopwatch = Stopwatch()..start();
      final tracedArguments = _traceParameters(tool, action.arguments);
      final result = await _connectorRegistry.execute(tool, action.arguments);
      actionStopwatch.stop();
      final tracedResult = _traceResult(tool, result.data, result.isError);
      final dataVolume = await _measureDataVolume(
        succeeded: !result.isError,
        requestArguments: tracedArguments,
        responseData: tracedResult,
      );
      if (!result.isError && dataVolume?.replayedOpSequence != null) {
        latestCitation = GroundedCitation(
          opSequence: dataVolume!.replayedOpSequence!,
          sourceLabel: tool,
          contextLabel: skill.id,
        );
      }
      traces.add(
        AgentActionTrace(
          title: 'Execute action',
          detail: tool,
          parameters: _traceParameters(tool, action.arguments),
          success: !result.isError,
          durationMs: actionStopwatch.elapsedMilliseconds,
          dataVolume: dataVolume,
        ),
      );
      // Traces stay redacted. toolResults stay complete so later steps
      // (pending answers, entity listing) can still read markdown.
      toolResults.add({
        'tool': tool,
        'arguments': action.arguments,
        'result': result.data,
        if (result.isError) 'error': result.errorCode,
      });

      if (result.isError) {
        if (result.errorCode == 'confirmation_required') {
          return AgentRunResult(
            handled: true,
            message: result.message ?? 'Confirm to save this locally.',
            traces: traces,
            pendingLifeTrackWrite: _pendingLifeTrackPayload(result.data),
            groundingState: GroundingState.ungrounded,
            safetyClass: safetyClass,
          );
        }
        return AgentRunResult(
          handled: true,
          message: result.message ?? 'The action failed.',
          traces: traces,
          isError: true,
          safetyClass: safetyClass,
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
          safetyClass: safetyClass,
        );
      }
    }

    return AgentRunResult(
      handled: true,
      message: 'The skill took too many steps and was stopped.',
      traces: traces,
      isError: true,
      safetyClass: safetyClass,
    );
  }

  Map<String, dynamic>? _pendingMap(Object? raw) {
    if (raw is! Map) return null;
    return raw.map((key, value) => MapEntry(key.toString(), value));
  }

  Map<String, dynamic>? _pendingLifeTrackPayload(Map<String, dynamic> data) {
    final pending = _pendingMap(data['pending']);
    if (pending == null) return null;
    final token = data['confirmation_token'];
    if (token is String && token.trim().isNotEmpty) {
      return {...pending, 'confirmation_token': token.trim()};
    }
    return pending;
  }

  Map<String, dynamic> _traceParameters(
    String tool,
    Map<String, dynamic> arguments,
  ) =>
      AddonTraceRedaction.connectorParameters(tool, arguments);

  Map<String, dynamic> _traceResult(
    String tool,
    Map<String, dynamic> data,
    bool isError,
  ) =>
      AddonTraceRedaction.connectorResult(tool, data, isError);

  /// Measures how much data a connector call actually moved.
  ///
  /// Never guesses: a failed call measures nothing (`null`), and a log
  /// citation is only attached when [_operationLogPort] resolves a real op.
  /// No connector in this orchestrator opens a network client, so bytes
  /// leaving the device is always the true zero the design's example shows,
  /// not an assumption.
  Future<DataVolumeMeasurement?> _measureDataVolume({
    required bool succeeded,
    required Map<String, dynamic> requestArguments,
    required Map<String, dynamic> responseData,
  }) async {
    if (!succeeded) return null;

    final bytesProcessed =
        utf8.encode(jsonEncode(requestArguments)).length +
        utf8.encode(jsonEncode(responseData)).length;

    final port = _operationLogPort;
    if (port == null) {
      return DataVolumeMeasurement(
        bytesProcessed: bytesProcessed,
        bytesLeftDevice: 0,
      );
    }

    final opsInLog = await port.count();
    if (opsInLog == 0) {
      return DataVolumeMeasurement(
        bytesProcessed: bytesProcessed,
        bytesLeftDevice: 0,
      );
    }

    final recent = await port.range(offset: 0, limit: 1);
    final MindOp? replayed = recent.isEmpty ? null : recent.first;
    return DataVolumeMeasurement(
      bytesProcessed: bytesProcessed,
      bytesLeftDevice: 0,
      opsInLog: opsInLog,
      replayedOpSequence: replayed?.sequence,
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
  final parsed = LLMJsonParser.parseObject(text);
  if (parsed.isFailure) return null;
  final decoded = parsed.value;
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
  return null;
}

String? parseSelectedSkillId(String text) {
  final parsed = LLMJsonParser.parseObject(text);
  if (parsed.isFailure) return null;
  return parsed.value['skill_id'] as String?;
}

String _formatEventTime(dynamic value) {
  final text = value?.toString() ?? '';
  if (text.length >= 16) return text.substring(11, 16);
  return text;
}

Map<String, dynamic> _calendarQueryArguments(
  String prompt,
  String today, {
  String? currentTime,
}) {
  final lower = prompt.toLowerCase();
  final arguments = <String, dynamic>{'date': today};
  if (lower.contains('next event') ||
      lower.contains('next meeting') ||
      lower.contains("what's next") ||
      lower.contains('whats next')) {
    final after = currentTime?.trim();
    if (after != null && after.isNotEmpty) {
      arguments['after'] = after.length >= 5 ? after.substring(0, 5) : after;
    }
    return arguments;
  }
  if (lower.contains('tomorrow')) {
    final parsed = DateTime.tryParse(today);
    if (parsed != null) {
      arguments['date'] = parsed
          .add(const Duration(days: 1))
          .toIso8601String()
          .substring(0, 10);
    }
    return arguments;
  }
  if (lower.contains('this week') || lower.contains('the week')) {
    final parsed = DateTime.tryParse(today);
    if (parsed != null) {
      arguments['end_date'] = parsed
          .add(const Duration(days: 6))
          .toIso8601String()
          .substring(0, 10);
    }
    return arguments;
  }
  final afterMatch = RegExp(
    r'after\s+(\d{1,2})(?::(\d{2}))?\s*(am|pm)?',
  ).firstMatch(lower);
  if (afterMatch != null) {
    var hour = int.parse(afterMatch.group(1)!);
    final minute = int.parse(afterMatch.group(2) ?? '0');
    final period = afterMatch.group(3);
    if (period == 'pm' && hour < 12) hour += 12;
    if (period == 'am' && hour == 12) hour = 0;
    arguments['after'] =
        '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }
  return arguments;
}

String _emptyCalendarMessage(String prompt) {
  final lower = prompt.toLowerCase();
  if (lower.contains('tomorrow')) {
    return 'You have no calendar events tomorrow.';
  }
  if (lower.contains('week')) {
    return 'You have no calendar events this week.';
  }
  return 'You have no calendar events today.';
}

String _summarizeCalendarEvents(List<dynamic> events) {
  final grouped = <String, List<String>>{};
  for (final event in events) {
    if (event is! Map) continue;
    final calendar = (event['calendar'] as String?)?.trim();
    final key = (calendar == null || calendar.isEmpty) ? 'Calendar' : calendar;
    grouped
        .putIfAbsent(key, () => [])
        .add('${_formatEventTime(event['start'])} ${event['title']}');
  }
  final buffer = StringBuffer('Here is your schedule:\n');
  if (grouped.length == 1) {
    buffer.write(grouped.values.single.join('\n'));
  } else {
    for (final entry in grouped.entries) {
      buffer
        ..writeln()
        ..writeln(entry.key)
        ..write(entry.value.join('\n'));
    }
  }
  return buffer.toString();
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
