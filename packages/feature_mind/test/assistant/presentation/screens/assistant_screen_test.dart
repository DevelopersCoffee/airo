import 'package:feature_mind/src/assistant/presentation/screens/assistant_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The AI half of the old Mind hub.
void main() {
  Widget wrap() =>
      const ProviderScope(child: MaterialApp(home: AssistantScreen()));

  testWidgets('keeps every AI action from the old hub', (tester) async {
    // Tall enough that the ListView builds all nine cards. The point of this
    // test is that none was dropped in the split, which a scroll-as-you-go
    // check would not prove.
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap());
    await tester.pump();

    for (final action in [
      'AI Chat',
      'Agent Skills',
      'Ask Image',
      'Audio Scribe',
      'Prompt Lab',
      'Mobile Actions & Tiny Garden',
      'Intelligence',
      'Device Capability Report',
      'Model Advisor',
    ]) {
      expect(
        find.text(action),
        findsOneWidget,
        reason:
            '$action was lost in '
            'the split.',
      );
    }
  });

  testWidgets('links to wellbeing rather than absorbing it', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pump();
    await tester.scrollUntilVisible(find.text('Reflection & Breathing'), 200);

    // Wellbeing is a destination, not a tab. The only way a person reaches it
    // is this card and the home grid, so its absence here would strand it.
    expect(find.text('Reflection & Breathing'), findsOneWidget);
    expect(find.text('Breathing Exercise'), findsNothing);
  });
}
