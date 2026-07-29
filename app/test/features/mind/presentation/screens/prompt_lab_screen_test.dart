import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:airo_app/features/mind/presentation/screens/prompt_lab_screen.dart';

void main() {
  testWidgets('Prompt Lab exposes negative prompt and runtime controls', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: PromptLabScreen()));
    expect(find.text('Prompt Lab'), findsOneWidget);
    expect(find.text('Negative prompt (optional)'), findsOneWidget);
    expect(find.textContaining('Temperature:'), findsOneWidget);
    expect(find.textContaining('Top-k:'), findsOneWidget);
    expect(find.textContaining('Maximum output:'), findsOneWidget);
  });

  testWidgets('image mode validates the local server before sending', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: PromptLabScreen()));
    await tester.tap(find.text('Image'));
    await tester.pump();

    await tester.enterText(find.byType(TextField).at(1), 'a quiet garden');
    await tester.scrollUntilVisible(
      find.text('Generate image'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Generate image'));
    await tester.pump();

    expect(
      find.text('Enter a valid local/private image server URL.'),
      findsOneWidget,
    );
  });
}
