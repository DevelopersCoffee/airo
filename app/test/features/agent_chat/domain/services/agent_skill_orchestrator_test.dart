import 'package:airo_app/features/agent_chat/data/connectors/calendar_connector.dart';
import 'package:airo_app/features/agent_chat/data/connectors/date_time_connector.dart';
import 'package:airo_app/features/agent_chat/data/connectors/notification_connector.dart';
import 'package:airo_app/features/agent_chat/domain/models/agent_skill.dart';
import 'package:airo_app/features/agent_chat/domain/services/agent_connector_registry.dart';
import 'package:airo_app/features/agent_chat/domain/services/agent_skill_orchestrator.dart';
import 'package:airo_app/features/agent_chat/domain/services/agent_skill_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AgentSkillOrchestrator', () {
    test('does not handle prompts when no skill applies', () async {
      final orchestrator = _buildOrchestrator();

      final result = await orchestrator.run('Split this bill');

      expect(result.handled, false);
    });

    test('runs calendar skill with date and calendar connectors', () async {
      final orchestrator = _buildOrchestrator();

      final result = await orchestrator.run('Check my schedule for today');

      expect(result.handled, true);
      expect(result.message, contains('no events scheduled'));
      expect(
        result.traces.map((trace) => trace.detail),
        containsAll([
          'read-calendar-events',
          'get_current_date_time',
          'read_calendar_events',
        ]),
      );
      expect(result.traces.last.parameters['date'], '2026-06-20');
    });

    test('summarizes calendar events when connector returns events', () async {
      final orchestrator = _buildOrchestrator(
        events: {
          '2026-06-20': const [
            CalendarEventData(
              title: 'Team standup',
              start: '2026-06-20T10:00:00+05:30',
              end: '2026-06-20T10:30:00+05:30',
              calendar: 'Work',
            ),
          ],
        },
      );

      final result = await orchestrator.run('What meetings do I have today?');

      expect(result.handled, true);
      expect(result.message, contains('Team standup'));
      expect(result.message, contains('10:00'));
    });

    test('schedules a daily notification reminder', () async {
      final notificationScheduler = InMemoryNotificationScheduler(
        now: () => DateTime(2026, 6, 20, 9, 3),
      );
      final orchestrator = _buildOrchestrator(
        notificationScheduler: notificationScheduler,
      );

      final result = await orchestrator.run(
        'Set a daily reminder at 9am to check my schedule for today.',
      );

      expect(result.handled, true);
      expect(result.message, contains('successfully scheduled for 9:00 AM'));
      expect(
        result.traces.map((trace) => trace.detail),
        containsAll(['schedule-notification', 'schedule_notification']),
      );
      expect(notificationScheduler.scheduled, hasLength(1));
      expect(
        notificationScheduler.scheduled.single.title,
        'Daily Schedule Check',
      );
      expect(
        notificationScheduler.scheduled.single.message,
        'Check your schedule for today.',
      );
      expect(notificationScheduler.scheduled.single.hour, 9);
      expect(notificationScheduler.scheduled.single.minute, 0);
      expect(notificationScheduler.scheduled.single.repeatDaily, true);
    });

    test('schedules a one-time notification for tomorrow', () async {
      final notificationScheduler = InMemoryNotificationScheduler(
        now: () => DateTime(2026, 6, 20, 9, 3),
      );
      final orchestrator = _buildOrchestrator(
        notificationScheduler: notificationScheduler,
      );

      final result = await orchestrator.run(
        'Create a reminder at 2:30pm tomorrow for "team meeting"',
      );

      expect(result.handled, true);
      expect(result.message, contains('"team meeting"'));
      expect(notificationScheduler.scheduled.single.title, 'team meeting');
      expect(notificationScheduler.scheduled.single.hour, 14);
      expect(notificationScheduler.scheduled.single.minute, 30);
      expect(notificationScheduler.scheduled.single.repeatDaily, false);
      expect(notificationScheduler.scheduled.single.date, '2026-06-21');
    });

    test('stops unsupported tool calls', () async {
      final orchestrator = _buildOrchestrator(
        modelClient: _UnsupportedToolModelClient(),
      );

      final result = await orchestrator.run('Check my schedule for today');

      expect(result.handled, true);
      expect(result.isError, true);
      expect(result.message, contains('unsupported action'));
    });

    test('builds skill-selection prompt from enabled skill summaries', () {
      final orchestrator = _buildOrchestrator();

      final prompt = orchestrator.buildSkillSelectionPrompt(
        'Check my schedule for today',
      );

      expect(prompt, contains('Available enabled skills'));
      expect(prompt, contains('read-calendar-events'));
      expect(prompt, contains('schedule-notification'));
      expect(prompt, isNot(contains('create-calendar-event')));
      expect(prompt, contains('Return JSON only'));
    });

    test(
      'blocks connectors when selected skill lacks required capability',
      () async {
        final orchestrator = _buildOrchestrator(
          skills: [
            AgentSkill(
              id: 'read-calendar-events',
              name: 'Read Calendar Events',
              description: 'Read calendar without declared capability.',
              instructions: 'Try to read calendar events.',
              tools: ['read_calendar_events'],
              capabilities: [],
            ),
          ],
          modelClient: _FixedActionModelClient(
            selectedSkillId: 'read-calendar-events',
            actions: [
              const SkillModelAction.toolCall(
                tool: 'read_calendar_events',
                arguments: {'date': '2026-06-20'},
              ),
            ],
          ),
        );

        final result = await orchestrator.run('Check my schedule for today');

        expect(result.handled, true);
        expect(result.isError, true);
        expect(result.message, contains('permission'));
        expect(result.traces.last.title, 'Blocked capability');
      },
    );

    test('returns an error for malformed model JSON actions', () async {
      final orchestrator = _buildOrchestrator(
        modelClient: _JsonModelClient(
          selectedSkillJson: '{"skill_id":"read-calendar-events"}',
          actionJson: 'not json',
        ),
      );

      final result = await orchestrator.run('Check my schedule for today');

      expect(result.handled, true);
      expect(result.isError, true);
      expect(result.message, contains('could not complete'));
    });

    test('stops after max tool steps', () async {
      final orchestrator = _buildOrchestrator(
        maxSteps: 1,
        modelClient: _FixedActionModelClient(
          selectedSkillId: 'read-calendar-events',
          actions: [
            const SkillModelAction.toolCall(tool: 'get_current_date_time'),
          ],
        ),
      );

      final result = await orchestrator.run('Check my schedule for today');

      expect(result.handled, true);
      expect(result.isError, true);
      expect(result.message, contains('too many steps'));
    });
  });
}

AgentSkillOrchestrator _buildOrchestrator({
  Map<String, List<CalendarEventData>>? events,
  InMemoryNotificationScheduler? notificationScheduler,
  AgentSkillModelClient? modelClient,
  List<AgentSkill>? skills,
  int maxSteps = 4,
}) {
  return AgentSkillOrchestrator(
    skillRegistry: AgentSkillRegistry(skills: skills),
    connectorRegistry: AgentConnectorRegistry(
      connectors: [
        DateTimeConnector(now: () => DateTime(2026, 6, 20, 9, 3)),
        InMemoryCalendarConnector(events: events),
        ScheduleNotificationConnector(
          scheduler: notificationScheduler ?? InMemoryNotificationScheduler(),
        ),
      ],
    ),
    modelClient: modelClient,
    maxSteps: maxSteps,
  );
}

class _UnsupportedToolModelClient implements AgentSkillModelClient {
  @override
  Future<String?> selectSkill({
    required String prompt,
    required List<AgentSkill> enabledSkills,
  }) async {
    return 'read-calendar-events';
  }

  @override
  Future<SkillModelAction?> nextAction({
    required String prompt,
    required AgentSkill skill,
    required List<Map<String, dynamic>> toolResults,
  }) async {
    return const SkillModelAction.toolCall(tool: 'delete_calendar_events');
  }
}

class _FixedActionModelClient implements AgentSkillModelClient {
  _FixedActionModelClient({
    required this.selectedSkillId,
    required List<SkillModelAction> actions,
  }) : _actions = List.of(actions);

  final String selectedSkillId;
  final List<SkillModelAction> _actions;

  @override
  Future<String?> selectSkill({
    required String prompt,
    required List<AgentSkill> enabledSkills,
  }) async {
    return selectedSkillId;
  }

  @override
  Future<SkillModelAction?> nextAction({
    required String prompt,
    required AgentSkill skill,
    required List<Map<String, dynamic>> toolResults,
  }) async {
    if (_actions.isEmpty) return null;
    return _actions.removeAt(0);
  }
}

class _JsonModelClient implements AgentSkillModelClient {
  const _JsonModelClient({
    required this.selectedSkillJson,
    required this.actionJson,
  });

  final String selectedSkillJson;
  final String actionJson;

  @override
  Future<String?> selectSkill({
    required String prompt,
    required List<AgentSkill> enabledSkills,
  }) async {
    return parseSelectedSkillId(selectedSkillJson);
  }

  @override
  Future<SkillModelAction?> nextAction({
    required String prompt,
    required AgentSkill skill,
    required List<Map<String, dynamic>> toolResults,
  }) async {
    return parseSkillModelAction(actionJson);
  }
}
