import 'package:airo_app/core/exploration/airo_explorable_collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('preserves search state when switching views', (tester) async {
    await tester.pumpWidget(_TestHost(items: _fixtureItems));

    await tester.enterText(
      find.byKey(const ValueKey('explorable_collection_search')),
      'skill',
    );
    await tester.pumpAndSettle();

    expect(find.text('Skill Console'), findsOneWidget);
    expect(find.text('Memory Vault'), findsNothing);

    await tester.tap(find.text('Place View'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('explorable_collection_spatial')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('explorable_spatial_item_skill-console')),
      findsOneWidget,
    );
    expect(find.text('Memory Vault'), findsNothing);
  });

  testWidgets('random selection respects the active category filter', (
    tester,
  ) async {
    AiroExplorableCollectionItem<String>? selected;

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
    await tester.tap(find.text('Automations').last);
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('explorable_collection_random')),
    );
    await tester.pumpAndSettle();

    expect(selected, isNotNull);
    expect(selected!.category, 'Automations');
    expect(find.byType(BottomSheet), findsOneWidget);
  });

  testWidgets('opens item details from the spatial view', (tester) async {
    await tester.pumpWidget(_TestHost(items: _fixtureItems));

    await tester.tap(find.text('Place View'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('explorable_spatial_item_memory-vault')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('Memory Vault'), findsWidgets);
    expect(find.text('Storage: Local'), findsOneWidget);
  });
}

class _TestHost extends StatelessWidget {
  const _TestHost({required this.items, this.onItemSelected});

  final List<AiroExplorableCollectionItem<String>> items;
  final ValueChanged<AiroExplorableCollectionItem<String>>? onItemSelected;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: Scaffold(
        body: AiroExplorableCollection<String>(
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
  AiroExplorableCollectionItem<String>(
    id: 'skill-console',
    title: 'Skill Console',
    subtitle: 'Airo skill discovery surface',
    category: 'Skills',
    group: 'Airo Home',
    details: 'Helps users compare local skills and trusted connectors.',
    tags: ['skill', 'connector'],
    metrics: {'Trust': 'Visible'},
    payload: 'skill',
  ),
  AiroExplorableCollectionItem<String>(
    id: 'memory-vault',
    title: 'Memory Vault',
    subtitle: 'Local context and recall',
    category: 'AI',
    group: 'Context Layer',
    details: 'Airo memory with retention and privacy expectations.',
    metrics: {'Storage': 'Local'},
    payload: 'memory',
  ),
  AiroExplorableCollectionItem<String>(
    id: 'routine-packs',
    title: 'Routine Packs',
    subtitle: 'Repeatable Airo workflows',
    category: 'Automations',
    group: 'Automation Layer',
    tags: ['routine'],
    payload: 'automation',
  ),
  AiroExplorableCollectionItem<String>(
    id: 'scheduled-actions',
    title: 'Scheduled Actions',
    subtitle: 'Time-based Airo automation',
    category: 'Automations',
    group: 'Automation Layer',
    payload: 'automation',
  ),
];
