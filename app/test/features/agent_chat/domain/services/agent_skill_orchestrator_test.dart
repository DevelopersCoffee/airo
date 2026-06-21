import 'package:airo_app/features/agent_chat/data/connectors/calendar_connector.dart';
import 'package:airo_app/features/agent_chat/data/connectors/date_time_connector.dart';
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
  AgentSkillModelClient? modelClient,
}) {
  return AgentSkillOrchestrator(
    skillRegistry: AgentSkillRegistry(),
    connectorRegistry: AgentConnectorRegistry(
      connectors: [
        DateTimeConnector(now: () => DateTime(2026, 6, 20, 9, 3)),
        InMemoryCalendarConnector(events: events),
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
