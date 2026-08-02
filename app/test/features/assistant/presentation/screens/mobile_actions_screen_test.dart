import 'package:airo_app/features/assistant/presentation/screens/mobile_actions_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows safe actions and updates Tiny Garden locally', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: MobileActionsScreen()));

    expect(find.text('Mobile Actions'), findsOneWidget);
    expect(find.text('Tiny Garden'), findsOneWidget);
    expect(find.text('Open Wi-Fi settings'), findsOneWidget);
    expect(find.text('Plant sunflower on plot 1'), findsOneWidget);

    final plantChip = find.ancestor(
      of: find.text('Plant sunflower on plot 1'),
      matching: find.byType(ActionChip),
    );
    await tester.scrollUntilVisible(
      plantChip,
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(plantChip);
    await tester.pump();
    expect(find.text('🌱'), findsOneWidget);
  });

  testWidgets('Tiny Garden plots expose accessible planted state', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: MobileActionsScreen()));

    expect(_plotSemantics('Tiny Garden plot 1, empty'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('1'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('1'));
    await tester.pump();

    expect(_plotSemantics('Tiny Garden plot 1, planted'), findsOneWidget);
  });
}

Finder _plotSemantics(String label) => find.byWidgetPredicate(
  (widget) => widget is Semantics && widget.properties.label == label,
);
