import 'package:feature_mind/src/capture/domain/live_insight.dart';
import 'package:feature_mind/src/capture/presentation/live_insights_rail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('expanded rail lists conversation IR facts', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LiveInsightsRail(
            expanded: true,
            onToggle: _noop,
            insights: [
              LiveInsight(
                kind: LiveInsightKind.decision,
                text: 'We decided Friday',
                evidence: 's0',
              ),
            ],
          ),
        ),
      ),
    );

    expect(
      find.byKey(const Key('meeting_capture_insights_list')),
      findsOneWidget,
    );
    expect(find.textContaining('Decision · We decided Friday'), findsOneWidget);
  });
}

void _noop() {}
