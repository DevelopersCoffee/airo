import 'package:airo_app/features/airo_explore/presentation/screens/airo_explore_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders Airo Explore and switches to map view', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AiroExploreScreen()));

    expect(find.text('Airo Explore'), findsOneWidget);
    expect(find.text('Index View'), findsOneWidget);
    expect(find.text('Map View'), findsOneWidget);
    expect(find.text('Mind Inbox'), findsOneWidget);
    expect(find.text('Model Library'), findsOneWidget);

    await tester.tap(find.text('Map View'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('explorable_collection_spatial')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('explorable_spatial_item_mind-inbox')),
      findsOneWidget,
    );
  });

  testWidgets('Airo search filters the shared dataset', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AiroExploreScreen()));

    await tester.enterText(
      find.byKey(const ValueKey('explorable_collection_search')),
      'memory',
    );
    await tester.pumpAndSettle();

    expect(find.text('Memory Vault'), findsOneWidget);
    expect(find.text('Mind Inbox'), findsNothing);
  });
}
