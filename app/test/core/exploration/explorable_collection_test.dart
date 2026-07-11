import 'package:airo_app/core/exploration/explorable_collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('preserves search state when switching views', (tester) async {
    await tester.pumpWidget(_TestHost(items: _fixtureItems));

    await tester.enterText(
      find.byKey(const ValueKey('explorable_collection_search')),
      'flight',
    );
    await tester.pumpAndSettle();

    expect(find.text('Flight Board'), findsOneWidget);
    expect(find.text('Breakfast Porter'), findsNothing);

    await tester.tap(find.text('Place View'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('explorable_collection_spatial')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('explorable_spatial_item_flight-board')),
      findsOneWidget,
    );
    expect(find.text('Breakfast Porter'), findsNothing);
  });

  testWidgets('random selection respects the active category filter', (
    tester,
  ) async {
    ExplorableCollectionItem<String>? selected;

    await tester.pumpWidget(
      _TestHost(
        items: _fixtureItems,
        onItemSelected: (item) => selected = item,
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey('explorable_collection_category')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Events').last);
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('explorable_collection_random')),
    );
    await tester.pumpAndSettle();

    expect(selected, isNotNull);
    expect(selected!.category, 'Events');
    expect(find.byType(BottomSheet), findsOneWidget);
  });

  testWidgets('opens item details from the spatial view', (tester) async {
    await tester.pumpWidget(_TestHost(items: _fixtureItems));

    await tester.tap(find.text('Place View'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('explorable_spatial_item_breakfast-porter')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('Breakfast Porter'), findsWidgets);
    expect(find.text('ABV: 5.3%'), findsOneWidget);
  });
}

class _TestHost extends StatelessWidget {
  const _TestHost({required this.items, this.onItemSelected});

  final List<ExplorableCollectionItem<String>> items;
  final ValueChanged<ExplorableCollectionItem<String>>? onItemSelected;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: Scaffold(
        body: ExplorableCollection<String>(
          title: 'Test Collection',
          subtitle: 'Shared data across views',
          items: items,
          randomSeed: 3,
          onItemSelected: onItemSelected,
        ),
      ),
    );
  }
}

const _fixtureItems = [
  ExplorableCollectionItem<String>(
    id: 'flight-board',
    title: 'Flight Board',
    subtitle: 'Sampler for discovery',
    category: 'Menu',
    group: 'Bar',
    details: 'Helps undecided guests compare pours.',
    tags: ['flight', 'sampler'],
    metrics: {'Pours': '4'},
    payload: 'menu',
  ),
  ExplorableCollectionItem<String>(
    id: 'breakfast-porter',
    title: 'Breakfast Porter',
    subtitle: 'Coffee-forward draft',
    category: 'Menu',
    group: 'Draft Wall',
    details: 'Dark beer with breakfast pairing notes.',
    metrics: {'ABV': '5.3%'},
    payload: 'menu',
  ),
  ExplorableCollectionItem<String>(
    id: 'open-mic',
    title: 'Open Mic',
    subtitle: 'Tuesday community event',
    category: 'Events',
    group: 'Stage',
    tags: ['music'],
    payload: 'event',
  ),
  ExplorableCollectionItem<String>(
    id: 'tour',
    title: 'Brewery Tour',
    subtitle: 'Saturday walkthrough',
    category: 'Events',
    group: 'Back House',
    payload: 'event',
  ),
];
