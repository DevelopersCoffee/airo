import 'package:airo_app/features/agent_chat/domain/models/agent_skill.dart';
import 'package:airo_app/features/agent_chat/domain/services/agent_skill_registry.dart';
import 'package:airo_app/features/agent_chat/presentation/widgets/manage_skills_sheet.dart';
import 'package:airo_app/features/agent_chat/presentation/widgets/skill_action_trace_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ManageSkillsSheet searches and toggles built-in skills', (
    tester,
  ) async {
    final registry = AgentSkillRegistry(
      skills: [_calendarSkill(), _routeSkill()],
    );
    var changes = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ManageSkillsSheet(
            registry: registry,
            onChanged: () => changes++,
          ),
        ),
      ),
    );

    expect(find.text('Manage Skills'), findsOneWidget);
    expect(find.text('calendar-today'), findsOneWidget);
    expect(find.text('open-airo-feature'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'route');
    await tester.pumpAndSettle();

    expect(find.text('calendar-today'), findsNothing);
    expect(find.text('open-airo-feature'), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(registry.getById('open-airo-feature')?.isEnabled, false);
    expect(changes, 1);
  });

  testWidgets('SkillActionTraceCard renders action traces and parameters', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SkillActionTraceCard(
            traces: [
              AgentActionTrace(
                title: 'Executed connector',
                detail: 'read_calendar_events',
                parameters: {'date': '2026-06-20'},
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Performed action'), findsOneWidget);
    expect(find.text('Executed connector'), findsOneWidget);
    expect(find.text('read_calendar_events'), findsOneWidget);
    expect(find.textContaining('2026-06-20'), findsOneWidget);
  });
}

AgentSkill _calendarSkill({bool enabled = true}) {
  return AgentSkill(
    id: 'calendar-today',
    name: 'Calendar Today',
    description: 'Check schedule.',
    enabled: enabled,
    capabilities: const [SkillCapability.calendarRead],
    tools: const ['get_current_date_time', 'read_calendar_events'],
    instructions: 'Use this for calendar questions.',
  );
}

AgentSkill _routeSkill({bool enabled = true}) {
  return AgentSkill(
    id: 'open-airo-feature',
    name: 'Open Airo Feature',
    description: 'Open app routes.',
    enabled: enabled,
    capabilities: const [SkillCapability.routeOpen],
    tools: const ['open_route'],
    instructions: 'Open app features.',
  );
}
