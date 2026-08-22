import 'package:core_ai/core_ai.dart';
import 'package:feature_mind/src/reasoning/reasoning_models.dart';
import 'package:feature_mind/src/reasoning/reasoning_tool_loop.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const request = MindReasoningRequest(
    userQuery: "What's on tomorrow?",
    intentKind: 'calendar_retrieval',
  );

  test('a direct answer is forwarded without executing tools', () async {
    var reasonCalls = 0;
    final events = runReasoningToolLoop(
      request: request,
      reason: (_) {
        reasonCalls++;
        return Stream.fromIterable(const [
          MindReasoningCompleted(
            answer: 'Nothing on the calendar.',
            reasoningSummary: 'Looked at the calendar.',
            level: MindReasoningLevel.none,
          ),
        ]);
      },
      executeTool: (_, __) async => fail('should not execute'),
    );

    await expectLater(
      events,
      emitsInOrder([
        isA<MindReasoningCompleted>().having(
          (e) => e.answer,
          'answer',
          'Nothing on the calendar.',
        ),
        emitsDone,
      ]),
    );
    expect(reasonCalls, 1);
  });

  test('none level runs one tool and skips a second model call', () async {
    var reasonCalls = 0;
    final executed = <String>[];
    final events = runReasoningToolLoop(
      request: request,
      reason: (_) {
        reasonCalls++;
        return Stream.fromIterable(const [
          MindReasoningCompleted(
            answer: '',
            reasoningSummary: 'Need calendar.',
            level: MindReasoningLevel.none,
            toolCalls: [
              MindReasoningToolCall(
                name: 'read_calendar_events',
                argumentsJson: '{"day":"tomorrow"}',
              ),
            ],
          ),
        ]);
      },
      executeTool: (name, args) async {
        executed.add('$name $args');
        return 'Three meetings tomorrow.';
      },
    );

    await expectLater(
      events,
      emitsInOrder([
        isA<MindReasoningToolStarted>().having(
          (e) => e.tool,
          'tool',
          'read_calendar_events',
        ),
        isA<MindReasoningToolCompleted>().having(
          (e) => e.tool,
          'tool',
          'read_calendar_events',
        ),
        isA<MindReasoningCompleted>()
            .having((e) => e.answer, 'answer', 'Three meetings tomorrow.')
            .having(
              (e) => e.toolCalls.single.name,
              'tool',
              'read_calendar_events',
            ),
        emitsDone,
      ]),
    );
    expect(reasonCalls, 1);
    expect(executed, ['read_calendar_events {"day":"tomorrow"}']);
  });

  test('light level feeds tool output into a second reason() call', () async {
    var reasonCalls = 0;
    final events = runReasoningToolLoop(
      request: const MindReasoningRequest(
        userQuery: 'Summarise tomorrow',
        intentKind: 'summarization',
        intentComplexity: 0.4,
      ),
      reason: (req) {
        reasonCalls++;
        if (req.toolResults.isEmpty) {
          return Stream.fromIterable(const [
            MindReasoningCompleted(
              answer: '',
              reasoningSummary: 'Need calendar.',
              level: MindReasoningLevel.light,
              toolCalls: [
                MindReasoningToolCall(
                  name: 'read_calendar_events',
                  argumentsJson: '{}',
                ),
              ],
            ),
          ]);
        }
        expect(req.toolResults.single.text, contains('a, b, c'));
        expect(
          req.toolResults.single.text,
          contains(ContextCompiler.dataBegin),
        );
        return Stream.fromIterable(const [
          MindReasoningCompleted(
            answer: 'You have three meetings.',
            reasoningSummary: 'Used the calendar.',
            level: MindReasoningLevel.light,
          ),
        ]);
      },
      executeTool: (_, __) async => 'a, b, c',
    );

    await expectLater(
      events,
      emitsInOrder([
        isA<MindReasoningToolStarted>(),
        isA<MindReasoningToolCompleted>(),
        isA<MindReasoningCompleted>().having(
          (e) => e.answer,
          'answer',
          'You have three meetings.',
        ),
        emitsDone,
      ]),
    );
    expect(reasonCalls, 2);
  });

  test('the loop stops at five tools', () async {
    var executes = 0;
    final events = runReasoningToolLoop(
      request: const MindReasoningRequest(
        userQuery: 'Keep going',
        intentKind: 'summarization',
        intentComplexity: 0.4,
      ),
      reason: (_) {
        return Stream.fromIterable(const [
          MindReasoningCompleted(
            answer: '',
            reasoningSummary: 'Need calendar.',
            level: MindReasoningLevel.light,
            toolCalls: [
              MindReasoningToolCall(
                name: 'read_calendar_events',
                argumentsJson: '{}',
              ),
            ],
          ),
        ]);
      },
      executeTool: (_, __) async {
        executes++;
        return 'ok';
      },
    );

    final collected = await events.toList();
    expect(executes, kMaxReasoningToolIterations);
    expect(
      collected.whereType<MindReasoningError>().single.message,
      kReasoningToolBudgetMessage,
    );
    expect(collected.whereType<MindReasoningCompleted>(), isEmpty);
  });

  test('decodeToolArguments accepts objects and rejects junk', () {
    expect(decodeToolArguments('{"day":"tomorrow"}'), {'day': 'tomorrow'});
    expect(decodeToolArguments('not json'), isEmpty);
    expect(decodeToolArguments('[]'), isEmpty);
  });
}
