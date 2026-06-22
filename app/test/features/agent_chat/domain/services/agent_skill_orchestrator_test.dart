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
      expect(result.message, contains('add this to your calendar'));
      expect(result.pendingCalendarEvent, isNotNull);
      expect(result.pendingCalendarEvent!['title'], 'Daily Schedule Check');
      expect(result.pendingCalendarEvent!['date'], '2026-06-20');
      expect(result.pendingCalendarEvent!['hour'], 9);
      expect(
        result.traces.map((trace) => trace.detail),
        containsAll([
          'schedule-notification',
          'get_current_date_time',
          'schedule_notification',
        ]),
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
      expect(result.message, contains('add this to your calendar'));
      expect(result.pendingCalendarEvent, isNotNull);
      expect(result.pendingCalendarEvent!['title'], 'team meeting');
      expect(result.pendingCalendarEvent!['date'], '2026-06-21');
      expect(result.pendingCalendarEvent!['hour'], 14);
      expect(result.pendingCalendarEvent!['minute'], 30);
      expect(notificationScheduler.scheduled.single.title, 'team meeting');
      expect(notificationScheduler.scheduled.single.hour, 14);
      expect(notificationScheduler.scheduled.single.minute, 30);
      expect(notificationScheduler.scheduled.single.repeatDaily, false);
      expect(notificationScheduler.scheduled.single.date, '2026-06-21');
    });

    test('schedules medicine reminders in a 12 hour window', () async {
      final notificationScheduler = InMemoryNotificationScheduler(
        now: () => DateTime(2026, 6, 20, 9, 3),
      );
      final orchestrator = _buildOrchestrator(
        notificationScheduler: notificationScheduler,
      );

      final result = await orchestrator.run(
        'Remind me to take Minoxidil every 12 hours starting at 8am',
      );

      expect(result.handled, true);
      expect(result.message, contains('2 medicine reminders'));
      expect(result.message, isNot(contains('add this to your calendar')));
      expect(result.pendingCalendarEvent, isNull);
      expect(notificationScheduler.scheduled, hasLength(2));
      expect(notificationScheduler.scheduled.first.category, 'medicine');
      expect(
        notificationScheduler.scheduled.first.scheduleType,
        'interval_hours',
      );
      expect(notificationScheduler.scheduled.first.hour, 8);
      expect(notificationScheduler.scheduled.last.hour, 20);
      expect(
        notificationScheduler.scheduled.first.metadata['medicine_name'],
        'Minoxidil',
      );
    });

    test('schedules medicine reminders relative to meals', () async {
      final notificationScheduler = InMemoryNotificationScheduler(
        now: () => DateTime(2026, 6, 20, 9, 3),
      );
      final orchestrator = _buildOrchestrator(
        notificationScheduler: notificationScheduler,
      );

      final result = await orchestrator.run(
        'Remind me to take Metformin after breakfast and dinner',
      );

      expect(result.handled, true);
      expect(notificationScheduler.scheduled, hasLength(2));
      expect(notificationScheduler.scheduled.first.hour, 8);
      expect(notificationScheduler.scheduled.first.minute, 30);
      expect(notificationScheduler.scheduled.last.hour, 20);
      expect(notificationScheduler.scheduled.last.minute, 30);
      expect(notificationScheduler.scheduled.first.category, 'medicine');
      expect(
        notificationScheduler.scheduled.first.scheduleType,
        'meal_relative',
      );
    });

    test('schedules family tasks from natural language', () async {
      final notificationScheduler = InMemoryNotificationScheduler(
        now: () => DateTime(2026, 6, 20, 9, 3),
      );
      final orchestrator = _buildOrchestrator(
        notificationScheduler: notificationScheduler,
      );

      final result = await orchestrator.run(
        'Drop my children to tuition every day at four o clock',
      );

      expect(result.handled, true);
      expect(
        notificationScheduler.scheduled.single.title,
        'Drop children to tuition',
      );
      expect(notificationScheduler.scheduled.single.hour, 4);
      expect(notificationScheduler.scheduled.single.category, 'family');
    });

    test('schedules due-date reminders until completed', () async {
      final notificationScheduler = InMemoryNotificationScheduler(
        now: () => DateTime(2026, 6, 20, 9, 3),
      );
      final orchestrator = _buildOrchestrator(
        notificationScheduler: notificationScheduler,
      );

      final result = await orchestrator.run(
        'Remind me to recharge my electricity bill tomorrow by tomorrow and keep asking until I do it',
      );

      expect(result.handled, true);
      expect(result.message, contains('keep asking until you mark it done'));
      expect(
        notificationScheduler.scheduled.single.title,
        'Recharge electricity bill',
      );
      expect(notificationScheduler.scheduled.single.category, 'billing');
      expect(notificationScheduler.scheduled.single.scheduleType, 'due_date');
      expect(notificationScheduler.scheduled.single.date, '2026-06-21');
      expect(notificationScheduler.scheduled.single.hour, 9);
      expect(notificationScheduler.scheduled.single.repeatDaily, true);
      expect(notificationScheduler.scheduled.single.requiresCompletion, true);
      expect(
        notificationScheduler.scheduled.single.followUpPolicy,
        'daily_until_done',
      );
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
  });
}

AgentSkillOrchestrator _buildOrchestrator({
  Map<String, List<CalendarEventData>>? events,
  InMemoryNotificationScheduler? notificationScheduler,
  AgentSkillModelClient? modelClient,
}) {
  return AgentSkillOrchestrator(
    skillRegistry: AgentSkillRegistry(),
    connectorRegistry: AgentConnectorRegistry(
      connectors: [
        DateTimeConnector(now: () => DateTime(2026, 6, 20, 9, 3)),
        InMemoryCalendarConnector(events: events),
        InMemoryCreateCalendarEventConnector(),
        ScheduleNotificationConnector(
          scheduler: notificationScheduler ?? InMemoryNotificationScheduler(),
        ),
      ],
    ),
    modelClient: modelClient,
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
