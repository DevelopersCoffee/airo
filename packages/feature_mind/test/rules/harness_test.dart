import 'package:feature_mind/feature_mind.dart';
import '../support/mind_rule_harness.dart';
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

/// A surface that obeys the rules.
class _CompliantSurface extends StatelessWidget {
  const _CompliantSurface();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        const MindPresencePip(isLocal: true),
        const MindNumberStrip(opCount: 12481, peerCount: 3, vaultSealed: true),
        MindContextChip(context: _context, onTap: () {}),
      ],
    ),
  );
}

/// A surface missing its presence pip.
class _NoPipSurface extends StatelessWidget {
  const _NoPipSurface();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        const MindNumberStrip(opCount: 1, peerCount: 0, vaultSealed: true),
        MindContextChip(context: _context, onTap: () {}),
      ],
    ),
  );
}

/// A surface whose tag is a bare Text — the decorative-tag failure R02 exists
/// to prevent.
class _DecorativeTagSurface extends StatelessWidget {
  const _DecorativeTagSurface();

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Column(
      children: [
        MindPresencePip(isLocal: true),
        MindNumberStrip(opCount: 1, peerCount: 0, vaultSealed: true),
        Text('#KneeSurgery2026'),
      ],
    ),
  );
}

void main() {
  testWidgets('the harness passes a compliant surface', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: _CompliantSurface()));

    await expectSatisfiesMindRules(tester);
  });

  testWidgets('the harness fails a surface with no presence pip', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: _NoPipSurface()));

    // Mutation test for R01: if this passes, the harness enforces nothing.
    await expectLater(
      () => expectSatisfiesMindRules(tester),
      throwsA(isA<TestFailure>()),
    );
  });

  testWidgets(
    'the harness fails a surface with no numbers when it claims them',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: MindPresencePip(isLocal: true))),
      );

      await expectLater(
        () => expectSatisfiesMindRules(tester),
        throwsA(isA<TestFailure>()),
      );
    },
  );

  testWidgets('a surface may opt out of the number strip explicitly', (
    tester,
  ) async {
    // A capture overlay has no status strip. Opting out is allowed; forgetting
    // is not, which is why the default is true.
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: MindPresencePip(isLocal: true))),
    );

    await expectSatisfiesMindRules(tester, expectsNumbers: false);
  });

  testWidgets('the harness fails a tag that is decoration', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: _DecorativeTagSurface()));

    // Mutation test for R02. A bare "#Tag" Text renders identically to a chip
    // and does nothing when tapped, which is exactly the failure to catch.
    await expectLater(
      () => expectSatisfiesMindRules(tester),
      throwsA(isA<TestFailure>()),
    );
  });
}
