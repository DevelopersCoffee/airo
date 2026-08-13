import 'package:feature_mind/feature_mind.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/mind_rule_harness.dart';
import '../support/surface_harness.dart';

void main() {
  testWidgets(
    'lists all five installed capabilities with sandbox limits on the row',
    (tester) async {
      await pumpSurface(
        tester,
        CapabilitiesSurface(runtime: FixtureMindRuntime()),
      );
      await tester.pumpAndSettle();

      expect(find.text('INSTALLED'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('Hospital Recovery'), findsOneWidget);
      expect(find.textContaining('v1.4'), findsOneWidget);
      expect(find.textContaining('38 items'), findsOneWidget);
      expect(find.text('Audio Scribe'), findsOneWidget);
      // Sandbox / consent limits printed on the row itself, per the design's
      // own stated rule -- never buried in a permissions sheet.
      expect(find.textContaining('consent-gated'), findsOneWidget);
      expect(find.textContaining('mic'), findsOneWidget);

      await expectSatisfiesMindRules(tester, expectsNumbers: false);
    },
  );

  testWidgets('the drafter renders in position, disabled', (tester) async {
    await pumpSurface(
      tester,
      CapabilitiesSurface(runtime: FixtureMindRuntime()),
    );
    await tester.pumpAndSettle();

    expect(find.text('BUILD ONE'), findsOneWidget);
    expect(
      find.textContaining("Manage my family's medical records"),
      findsOneWidget,
    );

    final draftButton = tester.widget<InkWell>(
      find
          .ancestor(
            of: find.text('DRAFT A CAPABILITY'),
            matching: find.byType(InkWell),
          )
          .first,
    );
    expect(
      draftButton.onTap,
      isNull,
      reason:
          'M20 builds the drafter; until then it must not respond to a '
          'tap that does nothing.',
    );
  });

  testWidgets('the community section renders in position, disabled', (
    tester,
  ) async {
    await pumpSurface(
      tester,
      CapabilitiesSurface(runtime: FixtureMindRuntime()),
    );
    await tester.pumpAndSettle();

    // Below the fold on a five-capability list at 390 x 844 -- scroll to it
    // the way a person would, rather than asserting on a widget tree that
    // includes content nobody has scrolled to see yet.
    await tester.dragUntilVisible(
      find.text('FROM THE COMMUNITY'),
      find.byType(ListView),
      const Offset(0, -200),
    );

    expect(find.text('FROM THE COMMUNITY'), findsOneWidget);
    expect(find.text('Startup Runway'), findsOneWidget);
    expect(find.text('Vehicle Service Log'), findsOneWidget);

    final getButtons = find.widgetWithText(InkWell, 'GET');
    expect(getButtons, findsNWidgets(2));
    for (var i = 0; i < 2; i++) {
      expect(tester.widget<InkWell>(getButtons.at(i)).onTap, isNull);
    }
  });

  testWidgets('tapping an installed capability opens its detail', (
    tester,
  ) async {
    await pumpSurface(
      tester,
      CapabilitiesSurface(runtime: FixtureMindRuntime()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Hospital Recovery'));
    await tester.pumpAndSettle();

    expect(find.text('REMOVE'), findsOneWidget);
    expect(find.textContaining('hospital_recovery'), findsOneWidget);
  });

  testWidgets('removing leaves the capability\'s contexts alone', (
    tester,
  ) async {
    final runtime = FixtureMindRuntime();
    await pumpSurface(tester, CapabilitiesSurface(runtime: runtime));
    await tester.pumpAndSettle();

    final contextsBefore = await runtime.contexts.all();

    await tester.tap(find.text('Hospital Recovery').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('REMOVE'));
    await tester.pumpAndSettle();
    // Confirmation dialog -- a destructive action does not fire on the first
    // tap alone.
    await tester.tap(find.text('REMOVE').last);
    await tester.pumpAndSettle();

    expect(find.text('Hospital Recovery'), findsNothing);
    final contextsAfter = await runtime.contexts.all();
    expect(contextsAfter, equals(contextsBefore));
  });

  testWidgets('reports the missing port when the runtime is partial', (
    tester,
  ) async {
    await pumpSurface(tester, CapabilitiesSurface(runtime: RustMindRuntime()));
    await tester.pumpAndSettle();

    expect(find.textContaining('CapabilityPort'), findsOneWidget);
  });

  testWidgets('golden — layout at 390 x 844', (tester) async {
    await pumpSurface(
      tester,
      CapabilitiesSurface(runtime: FixtureMindRuntime()),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(CapabilitiesSurface),
      matchesGoldenFile('goldens/capabilities.png'),
    );
  });
}
