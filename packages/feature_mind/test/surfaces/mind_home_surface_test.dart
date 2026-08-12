import 'package:feature_mind/feature_mind.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/mind_rule_harness.dart';
import '../support/surface_harness.dart';

void main() {
  testWidgets('is a runtime dashboard, not a feed', (tester) async {
    await pumpSurface(tester, MindHomeSurface(runtime: FixtureMindRuntime()));
    await tester.pumpAndSettle();

    // Ops, peers and vault are the point of the screen, and they sit above
    // everything else.
    expect(find.text('12,481 ops'), findsOneWidget);
    expect(find.text('3 on LAN'), findsOneWidget);
    expect(find.text('Sealed'), findsOneWidget);

    await expectSatisfiesMindRules(tester);
  });

  testWidgets('capture is one tap from here', (tester) async {
    await pumpSurface(tester, MindHomeSurface(runtime: FixtureMindRuntime()));
    await tester.pumpAndSettle();

    expect(find.text('VOICE'), findsOneWidget);
    expect(find.text('NOTE'), findsOneWidget);
    expect(find.text('SCAN'), findsOneWidget);
  });

  testWidgets('renders every active context as a tappable chip', (
    tester,
  ) async {
    var tapped = '';
    await pumpSurface(
      tester,
      MindHomeSurface(
        runtime: FixtureMindRuntime(),
        onOpenContext: (context) => tapped = context.label,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('4 ACTIVE'), findsOneWidget);
    expect(find.byType(MindContextChip), findsNWidgets(4));

    await tester.tap(find.text('#KneeSurgery2026'));
    expect(tapped, '#KneeSurgery2026');
  });

  testWidgets('lists installed capabilities with their item counts', (
    tester,
  ) async {
    await pumpSurface(tester, MindHomeSurface(runtime: FixtureMindRuntime()));
    await tester.pumpAndSettle();

    expect(find.text('Hospital Recovery'), findsOneWidget);
    expect(find.text('Audio Scribe'), findsOneWidget);
    expect(find.text('38 ITEMS'), findsOneWidget);
  });

  testWidgets('recent log rows carry their context and op number', (
    tester,
  ) async {
    await pumpSurface(tester, MindHomeSurface(runtime: FixtureMindRuntime()));
    await tester.pumpAndSettle();

    expect(find.text('Ibuprofen 400 mg logged'), findsOneWidget);
    expect(find.text('op 12,481'), findsOneWidget);
  });

  testWidgets('reports the missing port when the runtime is partial', (
    tester,
  ) async {
    await pumpSurface(tester, MindHomeSurface(runtime: RustMindRuntime()));
    await tester.pumpAndSettle();

    // Names the port, so a person learns the rest of the app works. And shows
    // no numbers: fabricating "0 ops" here would be a lie.
    expect(find.textContaining('OperationLogPort'), findsOneWidget);
    expect(find.byType(MindNumberStrip), findsNothing);
  });

  // Layout golden, not a typography one. `flutter test` loads no fonts, so
  // glyphs render as boxes; the design's three faces ship as .woff2, which
  // FontLoader cannot consume. This catches structure, spacing and overflow —
  // not copy or type. Reading it as proof of the design's look would be
  // exactly the kind of green that proves nothing.
  testWidgets('golden — layout at 390 x 844', (tester) async {
    await pumpSurface(tester, MindHomeSurface(runtime: FixtureMindRuntime()));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MindHomeSurface),
      matchesGoldenFile('goldens/mind_home.png'),
    );
  });
}
