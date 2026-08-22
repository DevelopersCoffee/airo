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

  test('clarify progress becomes chips, not a thinking step', () {
    final fold = ReasoningStreamFold();
    fold.add(const MindReasoningStageChanged(MindReasoningStage.understanding));
    fold.add(
      const MindReasoningProgress(
        'clarify:planning.create|calendar.retrieve|skill.execute',
      ),
    );
    fold.add(
      const MindReasoningError(
        'Do you mean planning your day, scheduling something on your calendar, or running a skill such as a meal plan?',
      ),
    );
    expect(fold.clarificationCandidates, [
      'planning.create',
      'calendar.retrieve',
      'skill.execute',
    ]);
    expect(fold.clarificationQuestion, contains('skill'));
    expect(fold.error, contains('calendar'));
    expect(fold.steps, [
      const ReasoningProgressStep(label: 'Reading your request'),
    ]);
    expect(fold.steps.any((s) => s.label.startsWith('clarify:')), isFalse);
  });

  test('completed tool calls land on the fold, not the step list', () {
    final fold = ReasoningStreamFold();
    fold.add(const MindReasoningToolStarted('read_calendar_events'));
    fold.add(const MindReasoningToolCompleted('read_calendar_events'));
    fold.add(
      const MindReasoningCompleted(
        answer: 'Three meetings.',
        reasoningSummary: 'Used the calendar.',
        level: MindReasoningLevel.none,
        toolCalls: [
          MindReasoningToolCall(
            name: 'read_calendar_events',
            argumentsJson: '{}',
          ),
        ],
      ),
    );
    expect(fold.toolCalls.single.name, 'read_calendar_events');
    expect(fold.steps, [
      const ReasoningProgressStep(label: 'Using read_calendar_events'),
      const ReasoningProgressStep(label: 'Finished read_calendar_events'),
    ]);
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
