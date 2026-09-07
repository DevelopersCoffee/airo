import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  BoxDecoration decorationOf(WidgetTester tester) {
    final container = tester
        .widgetList<Container>(
          find.descendant(
            of: find.byType(AiroBadge),
            matching: find.byType(Container),
          ),
        )
        .first;
    return container.decoration! as BoxDecoration;
  }

  testWidgets('live badge defaults to its 4px radius', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AiroBadge.live(pulse: false))),
    );

    final radius = decorationOf(tester).borderRadius! as BorderRadius;
    expect(radius.topLeft.x, 4.0);
  });

  testWidgets('borderRadius overrides the variant default', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AiroBadge.live(pulse: false, borderRadius: AiroSpacing.radiusSm),
        ),
      ),
    );

    final radius = decorationOf(tester).borderRadius! as BorderRadius;
    expect(radius.topLeft.x, AiroSpacing.radiusSm);
  });

  testWidgets('non-live badges stay pill-shaped unless overridden', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AiroBadge(label: 'PRO', variant: AiroBadgeVariant.pro),
        ),
      ),
    );

    final radius = decorationOf(tester).borderRadius! as BorderRadius;
    expect(radius.topLeft.x, 9999.0);
  });
}
