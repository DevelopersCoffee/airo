import 'package:feature_mind/feature_mind.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/mind_rule_harness.dart';
import '../support/surface_harness.dart';

void main() {
  testWidgets('graph, timeline and search are one switcher', (tester) async {
    await pumpSurface(
      tester,
      MemorySurface(
        runtime: FixtureMindRuntime(),
        contextId: 'kneesurgery2026',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MindProjectionSwitcher), findsOneWidget);
    await expectSatisfiesMindRules(tester);
  });

  testWidgets('graph is the default and shows linked contexts as nodes', (
    tester,
  ) async {
    await pumpSurface(
      tester,
      MemorySurface(
        runtime: FixtureMindRuntime(),
        contextId: 'kneesurgery2026',
      ),
    );
    await tester.pumpAndSettle();

    // #KneeSurgery2026 links to #Q3TaxFiling in the fixture. YOU is the
    // selected context; the link is the graph's whole reason to exist.
    expect(find.text('YOU'), findsOneWidget);
    expect(find.textContaining('Q3TaxFiling'), findsOneWidget);
  });

  testWidgets('switching to timeline shows this context\'s ops', (
    tester,
  ) async {
    await pumpSurface(
      tester,
      MemorySurface(
        runtime: FixtureMindRuntime(),
        contextId: 'kneesurgery2026',
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('TIMELINE'));
    await tester.pumpAndSettle();

    expect(find.text('Ibuprofen 400 mg logged'), findsOneWidget);
    // #Q3TaxFiling's own op must not leak into #KneeSurgery2026's timeline.
    expect(find.text('Receipt · hardware store, tiles'), findsNothing);
  });

  testWidgets('switching to search filters within this context', (
    tester,
  ) async {
    await pumpSurface(
      tester,
      MemorySurface(runtime: FixtureMindRuntime(), contextId: 'q3taxfiling'),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('SEARCH'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'contractor');
    await tester.pumpAndSettle();

    // The fixture's invoice title and its snippet both contain "Basu
    // Contracting", so asserting on the row's op number is the specific
    // claim: this exact hit surfaced, not just some text matching somewhere.
    expect(find.textContaining('op 12388'), findsOneWidget);
  });

  testWidgets('the sheet states crypto-shredding in plain words', (
    tester,
  ) async {
    await pumpSurface(
      tester,
      MemorySurface(
        runtime: FixtureMindRuntime(),
        contextId: 'kneesurgery2026',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('#KneeSurgery2026'), findsOneWidget);
    expect(find.textContaining('1,204 ops'), findsOneWidget);
    expect(
      find.textContaining('unreadable, forever'),
      findsOneWidget,
      reason:
          'R09/design: crypto-shredding must be stated at the moment of '
          'deletion, not implied.',
    );
  });

  testWidgets('destroy is offered but requires the real port', (tester) async {
    var previewed = false;
    await pumpSurface(
      tester,
      MemorySurface(
        runtime: FixtureMindRuntime(),
        contextId: 'kneesurgery2026',
        onDestroyRequested: (survivors) => previewed = survivors.isNotEmpty,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.key_off_outlined));
    await tester.pumpAndSettle();

    // The design links this context to #Q3TaxFiling, so destroying it must
    // preview that #Q3TaxFiling survives -- the whole point of the preview.
    expect(previewed, isTrue);
  });

  testWidgets('reports the missing port when the runtime is partial', (
    tester,
  ) async {
    await pumpSurface(
      tester,
      MemorySurface(runtime: RustMindRuntime(), contextId: 'kneesurgery2026'),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('ContextPort'), findsOneWidget);
  });

  testWidgets(
    'renders R01/R03 structure without overflow at 390 x 844',
    (tester) async {
      await pumpSurface(
        tester,
        MemorySurface(
          runtime: FixtureMindRuntime(),
          contextId: 'kneesurgery2026',
        ),
      );
      await tester.pumpAndSettle();

      // No pixel golden here -- this repo has no cross-platform-deterministic
      // golden infra (font rendering differs between the machine a golden was
      // captured on and CI), so R01/R04 above-the-fold and R03's single
      // switcher are asserted structurally instead, same as every other
      // surface in this package.
      expect(find.byType(MindPresencePip), findsOneWidget);
      expect(find.byType(MindProjectionSwitcher), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
