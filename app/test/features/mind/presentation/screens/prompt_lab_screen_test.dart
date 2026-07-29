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
}
