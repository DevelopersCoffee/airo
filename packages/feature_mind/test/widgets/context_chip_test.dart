import 'package:feature_mind/feature_mind.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _context = MindContext(
  id: 'kneesurgery2026',
  label: '#KneeSurgery2026',
  itemCount: 38,
  opCount: 1204,
  openedAtMs: 0,
  safetyClass: CapabilitySafetyClass.health,
);

void main() {
  testWidgets('R02 — a chip renders its label and its count', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MindContextChip(context: _context, onTap: () {}),
        ),
      ),
    );

    expect(find.text('#KneeSurgery2026'), findsOneWidget);
    expect(find.text('38'), findsOneWidget);
  });

  testWidgets('R02 — a chip is at least 48 logical pixels tall', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MindContextChip(context: _context, onTap: () {}),
        ),
      ),
    );

    final size = tester.getSize(find.byType(MindContextChip));
    expect(size.height, greaterThanOrEqualTo(MindContextChip.minimumTarget));
  });

  testWidgets('R02 — tapping a chip calls through', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MindContextChip(context: _context, onTap: () => taps++),
        ),
      ),
    );

    await tester.tap(find.byType(MindContextChip));
    expect(taps, 1);
  });

  testWidgets('R02 — a chip carries a semantic label naming its context', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MindContextChip(context: _context, onTap: () {}),
        ),
      ),
    );

    final semantics = tester.getSemantics(find.byType(MindContextChip));
    expect(semantics.label, contains('#KneeSurgery2026'));
    expect(semantics.label, contains('38'));
  });

  testWidgets(
    'R02 — a selected chip reads differently from an unselected one',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                MindContextChip(
                  context: _context,
                  onTap: () {},
                  isSelected: true,
                ),
                MindContextChip(context: _context, onTap: () {}),
              ],
            ),
          ),
        ),
      );

      final labels = tester
          .widgetList<Text>(find.text('#KneeSurgery2026'))
          .toList();
      expect(labels, hasLength(2));
      expect(labels.first.style?.color, isNot(labels.last.style?.color));
    },
  );
}
