import 'package:airo_app/features/agent_chat/domain/models/agent_skill.dart';
import 'package:airo_app/features/agent_chat/presentation/widgets/skill_action_trace_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('trace card renders success and failure states clearly', (
    tester,
  ) async {
    const traces = [
      AgentActionTrace(title: 'Load skill', detail: 'read-calendar-events'),
      AgentActionTrace(
        title: 'Blocked action',
        detail: 'delete_calendar_events',
        success: false,
      ),
    ];

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SkillActionTraceCard(traces: traces)),
      ),
    );

    expect(find.text('Performed action'), findsOneWidget);
    expect(find.text('Load skill'), findsOneWidget);
    expect(find.text('Blocked action'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.byIcon(Icons.circle), findsOneWidget);
  });

  testWidgets(
    'trace card renders parameters and hides itself for empty traces',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SkillActionTraceCard(
              traces: [
                AgentActionTrace(
                  title: 'Execute action',
                  detail: 'open_route',
                  parameters: {'feature': 'money'},
                ),
              ],
            ),
          ),
        ),
      );

      expect(
        find.textContaining('Parameters: {feature: money}'),
        findsOneWidget,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SkillActionTraceCard(traces: [])),
        ),
      );

      expect(find.text('Performed action'), findsNothing);
    },
  );
}
