import 'package:feature_mind/src/agent_chat/domain/models/agent_skill.dart';
import 'package:feature_mind/src/agent_chat/domain/models/data_volume_measurement.dart';
import 'package:feature_mind/src/agent_chat/presentation/widgets/skill_action_trace_card.dart';
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

  testWidgets(
    'renders a measured data-movement figure, and omits it when nothing was measured',
    (tester) async {
      const traces = [
        AgentActionTrace(
          title: 'Execute action',
          detail: 'query_lifetrack_status',
          dataVolume: DataVolumeMeasurement(
            bytesProcessed: 640,
            bytesLeftDevice: 0,
            opsInLog: 412,
            replayedOpSequence: 407,
          ),
        ),
        AgentActionTrace(title: 'Load skill', detail: 'query-lifetrack-status'),
      ];

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SkillActionTraceCard(traces: traces)),
        ),
      );

      expect(
        find.text(
          '412 ops in log · replayed op 407 · 0 bytes left this device',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('a failed tool call is shown, not swallowed', (tester) async {
    const traces = [
      AgentActionTrace(
        title: 'Execute action',
        detail: 'read_calendar_events',
        success: false,
      ),
    ];

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SkillActionTraceCard(traces: traces)),
      ),
    );

    expect(find.text('read_calendar_events'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
  });
}
