import 'package:feature_mind/src/host/assistant_host_adapter.dart';
import 'package:feature_mind/src/wellbeing/presentation/screens/wellbeing_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_assistant_host_adapter.dart';

/// The wellbeing half of the old Mind hub.
///
/// What matters here is the split itself: this screen keeps reflection and
/// breathing and must not have brought the AI lab along with it.
void main() {
  Widget wrap() => ProviderScope(
    overrides: [
      assistantHostAdapterProvider.overrideWithValue(
        FakeAssistantHostAdapter(),
      ),
    ],
    child: const MaterialApp(home: WellbeingScreen()),
  );

  testWidgets('keeps the three wellbeing actions', (tester) async {
    // The greeting card and the daily quote push "Reflection" (the third
    // action) below the default 800x600 test surface, so a plain pump()
    // leaves it unbuilt (ListView only realizes what's in the viewport). A
    // taller surface, not a scroll, is what the real device gets right.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(wrap());
    await tester.pump();

    expect(find.text('Daily Insight'), findsOneWidget);
    expect(find.text('Breathing Exercise'), findsOneWidget);
    expect(find.text('Reflection'), findsOneWidget);
  });

  testWidgets('does not carry the AI lab', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pump();

    for (final aiAction in [
      'AI Chat',
      'Agent Skills',
      'Prompt Lab',
      'Audio Scribe',
      'Model Management & Benchmark',
      'Model Advisor',
    ]) {
      expect(
        find.text(aiAction),
        findsNothing,
        reason:
            '"$aiAction" belongs to the assistant hub, not wellbeing. '
            'The split exists so a person is not sent to Wellbeing to tune a '
            'prompt.',
      );
    }
  });

  testWidgets('the breathing exercise opens its sheet', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pump();

    await tester.tap(find.text('Breathing Exercise'));
    await tester.pumpAndSettle();

    expect(find.text('1. Breathe in for 4 seconds.'), findsOneWidget);
  });
}
