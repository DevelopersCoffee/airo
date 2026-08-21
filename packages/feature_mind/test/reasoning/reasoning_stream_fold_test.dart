import 'package:feature_mind/src/reasoning/reasoning_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_bridges.dart';

void main() {
  test('the fold keeps the answer off the progress list', () {
    final fold = ReasoningStreamFold();
    fold.add(const MindReasoningStarted());
    fold.add(const MindReasoningStageChanged(MindReasoningStage.understanding));
    fold.add(const MindReasoningProgress('level=Standard'));
    fold.add(const MindReasoningAnswerDelta('Buy '));
    fold.add(const MindReasoningAnswerDelta('rice.'));
    fold.add(
      const MindReasoningCompleted(
        answer: 'Buy rice.',
        reasoningSummary: 'A short grocery plan.',
        level: MindReasoningLevel.light,
        confidence: 0.8,
      ),
    );

    expect(fold.answer, 'Buy rice.');
    expect(fold.reasoningSummary, 'A short grocery plan.');
    expect(fold.level, MindReasoningLevel.light);
    expect(fold.steps, [
      const ReasoningProgressStep(label: 'Reading your request'),
    ]);
    expect(fold.steps.any((s) => s.label.contains('Buy')), isFalse);
    expect(fold.steps.any((s) => s.label.contains('level=')), isFalse);
  });

  test('the fake bridge records the request and never exposes thoughts', () {
    final bridge = FakeMindGenerationBridge()
      ..reasoningEvents = const [
        MindReasoningCompleted(
          answer: 'Tuesday is free after 3.',
          reasoningSummary: 'Looked at the calendar.',
          level: MindReasoningLevel.none,
        ),
      ];

    const request = MindReasoningRequest(
      userQuery: "What's on Tuesday?",
      intentKind: 'calendar_retrieval',
      intentComplexity: 0.1,
    );

    expect(
      bridge.reason(request),
      emitsInOrder([
        isA<MindReasoningCompleted>().having(
          (e) => e.answer,
          'answer',
          "Tuesday is free after 3.",
        ),
      ]),
    );
    expect(bridge.lastReasonRequest?.intentKind, 'calendar_retrieval');
  });
}
