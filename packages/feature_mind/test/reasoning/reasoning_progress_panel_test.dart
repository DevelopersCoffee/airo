import 'package:feature_mind/src/reasoning/reasoning_models.dart';
import 'package:feature_mind/src/reasoning/reasoning_progress_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the panel titles the step count and hides itself when empty', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ReasoningProgressPanel(
            steps: [
              ReasoningProgressStep(label: 'Reading your request'),
              ReasoningProgressStep(label: 'Gathering context'),
            ],
            summary: 'Used the calendar, not a guess.',
          ),
        ),
      ),
    );

    expect(find.text('Thinking · 2 steps'), findsOneWidget);
    await tester.tap(find.text('Thinking · 2 steps'));
    await tester.pumpAndSettle();
    expect(find.text('Reading your request'), findsOneWidget);
    expect(find.text('Used the calendar, not a guess.'), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ReasoningProgressPanel(steps: [])),
      ),
    );
    expect(find.textContaining('Thinking'), findsNothing);
  });

  testWidgets('the panel never renders answer tokens as a thinking step', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ReasoningProgressPanel(
            steps: [ReasoningProgressStep(label: 'Writing an answer')],
            inProgress: true,
          ),
        ),
      ),
    );

    expect(find.text('Thinking · 1 step'), findsOneWidget);
    expect(find.text('Buy rice tomorrow.'), findsNothing);
  });

  testWidgets('a restored summary-only panel uses Thinking, not 0 steps', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ReasoningProgressPanel(
            steps: [],
            summary: 'Used density, not a scratchpad.',
          ),
        ),
      ),
    );

    expect(find.text('Thinking'), findsOneWidget);
    expect(find.textContaining('0 steps'), findsNothing);
    await tester.tap(find.text('Thinking'));
    await tester.pumpAndSettle();
    expect(find.text('Used density, not a scratchpad.'), findsOneWidget);
  });
}
