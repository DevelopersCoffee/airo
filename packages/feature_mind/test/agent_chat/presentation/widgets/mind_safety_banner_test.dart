import 'package:feature_mind/src/agent_chat/presentation/widgets/mind_safety_banner.dart';
import 'package:feature_mind/src/runtime/models/capability_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MindSafetyBanner', () {
    testWidgets('renders nothing without a safety class', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: MindSafetyBanner())),
      );

      expect(find.byKey(const Key('mind.safetyBanner')), findsNothing);
    });

    testWidgets('renders nothing for the general safety class', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MindSafetyBanner(safetyClass: CapabilitySafetyClass.general),
          ),
        ),
      );

      expect(find.byKey(const Key('mind.safetyBanner')), findsNothing);
    });

    testWidgets('renders the wellness-only notice for the health class', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MindSafetyBanner(safetyClass: CapabilitySafetyClass.health),
          ),
        ),
      );

      expect(find.byKey(const Key('mind.safetyBanner')), findsOneWidget);
      expect(find.textContaining('wellness only'), findsOneWidget);
      expect(find.textContaining('dosage'), findsOneWidget);
    });

    testWidgets('financial and legal classes render distinct copy', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MindSafetyBanner(
              safetyClass: CapabilitySafetyClass.financial,
            ),
          ),
        ),
      );
      expect(find.textContaining('trade'), findsOneWidget);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MindSafetyBanner(safetyClass: CapabilitySafetyClass.legal),
          ),
        ),
      );
      expect(find.textContaining('file or submit'), findsOneWidget);
    });
  });
}
