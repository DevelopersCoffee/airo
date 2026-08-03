import 'package:feature_mind/feature_mind.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('R03 — all three projections are on one control', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MindProjectionSwitcher(
            selected: ProjectionKind.graph,
            onChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('GRAPH'), findsOneWidget);
    expect(find.text('TIMELINE'), findsOneWidget);
    expect(find.text('SEARCH'), findsOneWidget);
  });

  testWidgets('R03 — selecting a projection reports which, not a route', (
    tester,
  ) async {
    ProjectionKind? chosen;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MindProjectionSwitcher(
            selected: ProjectionKind.graph,
            onChanged: (kind) => chosen = kind,
          ),
        ),
      ),
    );

    await tester.tap(find.text('SEARCH'));
    expect(chosen, ProjectionKind.search);
  });

  testWidgets('R03 — every segment meets the 48px target', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MindProjectionSwitcher(
            selected: ProjectionKind.timeline,
            onChanged: (_) {},
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byType(MindProjectionSwitcher)).height,
      greaterThanOrEqualTo(48),
    );
  });

  testWidgets('R03 — the selected segment is distinguishable', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MindProjectionSwitcher(
            selected: ProjectionKind.timeline,
            onChanged: (_) {},
          ),
        ),
      ),
    );

    final selected = tester.widget<Text>(find.text('TIMELINE'));
    final other = tester.widget<Text>(find.text('GRAPH'));
    expect(selected.style?.color, isNot(other.style?.color));
  });
}
