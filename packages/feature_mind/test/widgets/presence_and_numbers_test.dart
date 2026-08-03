import 'package:feature_mind/feature_mind.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('R01 presence', () {
    testWidgets('local work is teal and says so', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: MindPresencePip(isLocal: true))),
      );

      expect(find.text('ON-DEVICE'), findsOneWidget);
      final pip = tester.widget<Container>(
        find.byKey(const Key('mind.presence.dot')),
      );
      expect(
        (pip.decoration! as BoxDecoration).color,
        MindPresencePip.localColour,
      );
    });

    testWidgets('remote work is not teal and names where it ran', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MindPresencePip(isLocal: false, remoteLabel: 'iPad Air'),
          ),
        ),
      );

      expect(find.text('iPad Air'), findsOneWidget);
      final pip = tester.widget<Container>(
        find.byKey(const Key('mind.presence.dot')),
      );
      expect(
        (pip.decoration! as BoxDecoration).color,
        isNot(MindPresencePip.localColour),
      );
    });

    testWidgets('remote work with no label still does not claim locality', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: MindPresencePip(isLocal: false)),
        ),
      );

      expect(find.text('ON-DEVICE'), findsNothing);
      expect(find.text('ELSEWHERE'), findsOneWidget);
    });

    testWidgets('the pip is readable to a screen reader', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: MindPresencePip(isLocal: true))),
      );

      expect(
        tester.getSemantics(find.byType(MindPresencePip)).label,
        contains('this device'),
      );
    });
  });

  group('R04 numbers', () {
    testWidgets('shows ops, peers and vault state as numbers', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MindNumberStrip(
              opCount: 12481,
              peerCount: 3,
              vaultSealed: true,
            ),
          ),
        ),
      );

      expect(find.text('12,481 ops'), findsOneWidget);
      expect(find.text('3 on LAN'), findsOneWidget);
      expect(find.text('Sealed'), findsOneWidget);
    });

    testWidgets('zero peers is a number, not an empty slot', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MindNumberStrip(opCount: 0, peerCount: 0, vaultSealed: false),
          ),
        ),
      );

      expect(find.text('0 ops'), findsOneWidget);
      expect(find.text('0 on LAN'), findsOneWidget);
      expect(find.text('Unsealed'), findsOneWidget);
    });

    testWidgets('groups thousands so the count reads at a glance', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MindNumberStrip(
              opCount: 1234567,
              peerCount: 1,
              vaultSealed: true,
            ),
          ),
        ),
      );

      expect(find.text('1,234,567 ops'), findsOneWidget);
    });
  });
}
