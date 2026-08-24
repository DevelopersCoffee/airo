import 'package:feature_mind/src/capture/domain/live_insight.dart';
import 'package:feature_mind/src/capture/presentation/live_insights_rail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host({required bool expanded, List<LiveInsight> insights = const []}) =>
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 600,
          child: LiveInsightsRail(
            expanded: expanded,
            onToggle: () {},
            insights: insights,
          ),
        ),
      ),
    );

void main() {
  testWidgets('collapsed rail shows the expand affordance', (tester) async {
    await tester.pumpWidget(_host(expanded: false));
    expect(
      find.byKey(const Key('meeting_capture_insights_expand')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('meeting_capture_insights_list')),
      findsNothing,
    );
  });

  testWidgets('expanded rail with no insights shows the empty state', (
    tester,
  ) async {
    await tester.pumpWidget(_host(expanded: true));
    expect(find.textContaining('will appear here'), findsOneWidget);
    expect(
      find.byKey(const Key('meeting_capture_insights_list')),
      findsNothing,
    );
  });

  testWidgets('expanded rail renders high-confidence insights only', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        expanded: true,
        insights: const [
          LiveInsight(
            kind: LiveInsightKind.decision,
            text: 'Migration deadline: Friday',
            confidence: 0.9,
          ),
          LiveInsight(
            kind: LiveInsightKind.action,
            text: 'database changes',
            confidence: 0.82,
            detail: 'Uday',
          ),
          LiveInsight(
            kind: LiveInsightKind.topic,
            text: 'speculative aside',
            confidence: 0.3,
          ),
        ],
      ),
    );

    expect(
      find.byKey(const Key('meeting_capture_insights_list')),
      findsOneWidget,
    );
    expect(find.text('Migration deadline: Friday'), findsOneWidget);
    expect(find.text('database changes'), findsOneWidget);
    expect(find.text('Uday'), findsOneWidget);
    // Low-confidence insight is hidden (no speculative insights).
    expect(find.text('speculative aside'), findsNothing);
    // Empty-state copy is gone once real insights render.
    expect(find.textContaining('will appear here'), findsNothing);
  });
}
