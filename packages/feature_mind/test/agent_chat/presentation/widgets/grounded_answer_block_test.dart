import 'package:feature_mind/src/agent_chat/domain/models/grounded_citation.dart';
import 'package:feature_mind/src/agent_chat/presentation/widgets/grounded_answer_block.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GroundedAnswerBlock', () {
    testWidgets('renders nothing when grounding does not apply', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GroundedAnswerBlock(state: GroundingState.notApplicable),
          ),
        ),
      );

      expect(find.text('GROUNDED IN'), findsNothing);
      expect(find.textContaining('UNGROUNDED'), findsNothing);
    });

    testWidgets('renders a GROUNDED IN header and a tappable citation chip', (
      tester,
    ) async {
      GroundedCitation? tapped;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GroundedAnswerBlock(
              state: GroundingState.grounded,
              citations: const [
                GroundedCitation(
                  opSequence: 412,
                  sourceLabel: 'LifeTrack query',
                  contextLabel: 'KneeSurgery2026',
                ),
              ],
              onCitationTap: (citation) => tapped = citation,
            ),
          ),
        ),
      );

      expect(find.text('GROUNDED IN'), findsOneWidget);
      expect(find.textContaining('op 412'), findsOneWidget);
      expect(find.textContaining('KneeSurgery2026'), findsOneWidget);

      final chipSize = tester.getSize(find.byType(InkWell).first);
      expect(chipSize.height, greaterThanOrEqualTo(48));

      await tester.tap(find.byType(InkWell).first);
      expect(tapped?.opSequence, 412);
    });

    testWidgets('labels an ungrounded answer instead of hiding it', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GroundedAnswerBlock(state: GroundingState.ungrounded),
          ),
        ),
      );

      expect(find.textContaining('UNGROUNDED'), findsOneWidget);
      expect(find.text('GROUNDED IN'), findsNothing);
    });

    testWidgets(
      'a grounded state with no citations renders as ungrounded rather than silently grounded',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: GroundedAnswerBlock(
                state: GroundingState.grounded,
                citations: [],
              ),
            ),
          ),
        );

        expect(find.text('GROUNDED IN'), findsNothing);
        expect(find.textContaining('UNGROUNDED'), findsOneWidget);
      },
    );
  });
}
