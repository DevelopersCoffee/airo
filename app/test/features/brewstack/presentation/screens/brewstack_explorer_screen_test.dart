import 'package:airo_app/features/brewstack/presentation/screens/brewstack_explorer_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders BrewStack v2 explorer and switches to venue view', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: BrewStackExplorerScreen()));

    expect(find.text('BrewStack v2'), findsOneWidget);
    expect(find.text('Ops View'), findsOneWidget);
    expect(find.text('Venue View'), findsOneWidget);
    expect(find.text('Table 12'), findsOneWidget);
    expect(find.text('Monsoon IPA'), findsOneWidget);

    await tester.tap(find.text('Venue View'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('explorable_collection_spatial')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('explorable_spatial_item_taproom-table-12')),
      findsOneWidget,
    );
  });

  testWidgets('BrewStack search filters the shared dataset', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: BrewStackExplorerScreen()));

    await tester.enterText(
      find.byKey(const ValueKey('explorable_collection_search')),
      'trivia',
    );
    await tester.pumpAndSettle();

    expect(find.text('Trivia Night'), findsOneWidget);
    expect(find.text('Table 12'), findsNothing);
  });
}
