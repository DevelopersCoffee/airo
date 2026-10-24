import 'package:core_ai/core_ai.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const clock = LiteRtLmToolSpec(
    name: 'get_current_date_time',
    description: 'Current local time.',
  );

  test('parses a structured LiteRT reply and a legacy string', () {
    final reply = LiteRtLmReply.fromChannel({
      'text': 'checking',
      'toolCalls': [
        {
          'name': 'get_current_date_time',
          'arguments': {'unused': false},
        },
      ],
    });

    expect(reply.text, 'checking');
    expect(reply.toolCalls.single.name, 'get_current_date_time');
    expect(reply.toolCalls.single.arguments['unused'], isFalse);
    expect(LiteRtLmReply.fromChannel('plain').text, 'plain');
    expect(LiteRtLmReply.fromChannel('plain').toolCalls, isEmpty);
  });

  test('executes an allowed tool and returns the follow-up text', () async {
    final prompts = <String>[];
    final executed = <String>[];
    final text = await completeLiteRtWithTools(
      prompt: 'what time is it',
      tools: const [clock],
      execute: (name, arguments) async {
        executed.add(name);
        return 'Friday 16:00';
      },
      generate:
          ({
            required String prompt,
            required List<LiteRtLmToolSpec> tools,
            required List<LiteRtLmToolResponse> toolResponses,
          }) async {
            prompts.add(prompt);
            if (toolResponses.isEmpty) {
              return const LiteRtLmReply(
                text: '',
                toolCalls: [LiteRtLmToolCall(name: 'get_current_date_time')],
              );
            }
            return LiteRtLmReply(
              text: 'It is ${toolResponses.single.response}.',
            );
          },
    );

    expect(executed, ['get_current_date_time']);
    expect(prompts, ['what time is it', '']);
    expect(text, 'It is Friday 16:00.');
  });

  test('does not execute a tool outside the allowlist', () async {
    final executed = <String>[];
    final text = await completeLiteRtWithTools(
      prompt: 'turn on the flashlight',
      tools: const [clock],
      execute: (name, arguments) async {
        executed.add(name);
        return 'should-not-run';
      },
      generate:
          ({
            required String prompt,
            required List<LiteRtLmToolSpec> tools,
            required List<LiteRtLmToolResponse> toolResponses,
          }) async {
            if (toolResponses.isEmpty) {
              return const LiteRtLmReply(
                text: '',
                toolCalls: [LiteRtLmToolCall(name: 'set_flashlight')],
              );
            }
            return LiteRtLmReply(text: toolResponses.single.response);
          },
    );

    expect(executed, isEmpty);
    expect(text, 'Tool set_flashlight is not available.');
  });

  test('runs a text-format tool call and hides the tag', () async {
    Map<String, Object?>? seen;
    final text = await completeLiteRtWithTools(
      prompt: 'show my budget',
      tools: const [
        LiteRtLmToolSpec(name: 'open_route', description: 'Open a screen.'),
      ],
      execute: (name, arguments) async {
        seen = arguments;
        return '{"route":"/money/budgets","message":"Opening Budgets."}';
      },
      generate:
          ({
            required String prompt,
            required List<LiteRtLmToolSpec> tools,
            required List<LiteRtLmToolResponse> toolResponses,
          }) async {
            return const LiteRtLmReply(
              text: '<open_route>{target:budget}</open_route>',
            );
          },
    );

    expect(seen, {'target': 'budget'});
    expect(text, 'Opening Budgets.');
    expect(
      liteRtTextToolCalls(
        '<schedule_notification>{title:Medicine,message:Take it,hour:7,minute:30,repeat_daily:true}</schedule_notification>',
      ).single.arguments,
      {
        'title': 'Medicine',
        'message': 'Take it',
        'hour': 7,
        'minute': 30,
        'repeat_daily': true,
      },
    );
  });

  test('stops after the tool budget', () async {
    var rounds = 0;
    final text = await completeLiteRtWithTools(
      prompt: 'loop',
      tools: const [clock],
      maxIterations: 2,
      execute: (name, arguments) async => 'again',
      generate:
          ({
            required String prompt,
            required List<LiteRtLmToolSpec> tools,
            required List<LiteRtLmToolResponse> toolResponses,
          }) async {
            rounds += 1;
            return const LiteRtLmReply(
              text: '',
              toolCalls: [LiteRtLmToolCall(name: 'get_current_date_time')],
            );
          },
    );

    expect(rounds, 3);
    expect(text, kLiteRtToolBudgetMessage);
  });
}
