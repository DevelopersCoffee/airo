import 'package:feature_mind/feature_mind.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/mind_rule_harness.dart';
import '../support/surface_harness.dart';

void main() {
  testWidgets('shows the package size broken down by content class', (
    tester,
  ) async {
    await pumpSurface(
      tester,
      PortabilitySurface(runtime: FixtureMindRuntime()),
    );
    await tester.pumpAndSettle();

    expect(find.text('RECOVERY PACKAGE'), findsOneWidget);
    expect(find.textContaining('.airobackup'), findsOneWidget);
    expect(find.textContaining('SCANS'), findsOneWidget);
    expect(find.textContaining('AUDIO'), findsOneWidget);
    // Not a bare "LOG" -- the always-present number strip has its own "LOG"
    // label for the op count, so the content-class legend needs its full
    // text to be unambiguous.
    expect(find.textContaining('LOG 390MB'), findsOneWidget);

    await expectSatisfiesMindRules(tester, expectsNumbers: false);
  });

  testWidgets(
    'every context but the design\'s own excluded example starts selected',
    (tester) async {
      await pumpSurface(
        tester,
        PortabilitySurface(runtime: FixtureMindRuntime()),
      );
      await tester.pumpAndSettle();

      expect(find.text('#KneeSurgery2026'), findsOneWidget);
      expect(find.text('#DowntownApartment'), findsOneWidget);
      expect(find.text('#Q3TaxFiling'), findsOneWidget);
      expect(find.text('#AiroArchitecture'), findsOneWidget);

      // The design itself leaves #AiroArchitecture unchecked as its example
      // of a deliberate exclusion -- three checked, one not, not all four.
      final checkboxes = find.byType(Checkbox);
      expect(checkboxes, findsNWidgets(4));
      for (var i = 0; i < 3; i++) {
        expect(tester.widget<Checkbox>(checkboxes.at(i)).value, isTrue);
      }
      expect(tester.widget<Checkbox>(checkboxes.at(3)).value, isFalse);
    },
  );

  testWidgets('unchecking a context actually shrinks the package size', (
    tester,
  ) async {
    await pumpSurface(
      tester,
      PortabilitySurface(runtime: FixtureMindRuntime()),
    );
    await tester.pumpAndSettle();

    String sizeText() =>
        (tester.widget<Text>(find.byKey(const Key('portability.size'))).data)!;
    final before = sizeText();

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();

    // A size that does not move when a context is unchecked would tell the
    // person their choice did nothing, which is the exact failure the
    // design's recompute-on-selection rule exists to prevent.
    expect(sizeText(), isNot(equals(before)));
  });

  testWidgets('the passphrase warning is stated before sealing, not after', (
    tester,
  ) async {
    await pumpSurface(
      tester,
      PortabilitySurface(runtime: FixtureMindRuntime()),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('there is no reset'), findsOneWidget);
  });

  testWidgets('sealing is disabled until a passphrase is entered', (
    tester,
  ) async {
    await pumpSurface(
      tester,
      PortabilitySurface(runtime: FixtureMindRuntime()),
    );
    await tester.pumpAndSettle();

    final sealButton = tester.widget<InkWell>(
      find
          .ancestor(
            of: find.text('SEAL PACKAGE'),
            matching: find.byType(InkWell),
          )
          .first,
    );
    expect(sealButton.onTap, isNull);

    await tester.enterText(find.byType(TextField), 'correct horse battery');
    await tester.pumpAndSettle();

    final sealButtonAfter = tester.widget<InkWell>(
      find
          .ancestor(
            of: find.text('SEAL PACKAGE'),
            matching: find.byType(InkWell),
          )
          .first,
    );
    expect(sealButtonAfter.onTap, isNotNull);
  });

  testWidgets('none of the three destinations is a server', (tester) async {
    await pumpSurface(
      tester,
      PortabilitySurface(runtime: FixtureMindRuntime()),
    );
    await tester.pumpAndSettle();

    // The destination row sits below the package card, four context rows and
    // the passphrase field -- below the fold at 390 x 844.
    await tester.dragUntilVisible(
      find.text('THIS DEVICE'),
      find.byType(ListView),
      const Offset(0, -300),
    );

    // Not a bare "LAN" -- the always-present number strip also says
    // "0 on LAN" for the peer count.
    expect(find.text('iPad · LAN'), findsOneWidget);
    expect(find.text('THIS DEVICE'), findsOneWidget);
    expect(find.text('USB DRIVE'), findsOneWidget);
    expect(find.textContaining('server'), findsNothing);
  });

  testWidgets('sealing reports progress and completes', (tester) async {
    await pumpSurface(
      tester,
      PortabilitySurface(runtime: FixtureMindRuntime()),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'correct horse battery');
    await tester.pumpAndSettle();

    await tester.tap(find.text('SEAL PACKAGE'));
    await tester.pump();
    // Mid-seal: the fixture's stream yields five steps, not an instant jump.
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();
    // Not a bare "Sealed" -- the number strip's vault cell also reads
    // "Sealed".
    expect(find.text('Sealed · ready to send'), findsOneWidget);
  });

  testWidgets('reports the missing port when the runtime is partial', (
    tester,
  ) async {
    await pumpSurface(tester, PortabilitySurface(runtime: RustMindRuntime()));
    await tester.pumpAndSettle();

    expect(find.textContaining('ContextPort'), findsOneWidget);
  });

  testWidgets('golden — layout at 390 x 844', (tester) async {
    await pumpSurface(
      tester,
      PortabilitySurface(runtime: FixtureMindRuntime()),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(PortabilitySurface),
      matchesGoldenFile('goldens/portability.png'),
    );
  });
}
