import 'package:feature_mind/src/agent_chat/data/services/assistant_grounded_reply.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AssistantGroundedReply', () {
    test('answers capability questions without opening a feature', () {
      expect(
        AssistantGroundedReply.tryHandle(prompt: 'what can u do'),
        contains('check your schedule'),
      );
      expect(
        AssistantGroundedReply.tryHandle(prompt: 'What can you do in Airo?'),
        contains('draft diet plans'),
      );
      expect(
        AssistantGroundedReply.tryHandle(
          prompt: 'what can Airo do for reminders?',
        ),
        isNull,
      );
    });

    test('answers selected-model and training questions from local facts', () {
      expect(
        AssistantGroundedReply.tryHandle(
          prompt: 'what model we are usig',
          selectedModelName: 'Gemma 2 2B Instruct',
          selectedModelId: 'gemma-2-2b-it-q4_k_m',
        ),
        contains('Gemma 2 2B Instruct'),
      );
      expect(
        AssistantGroundedReply.tryHandle(
          prompt: 'when was the last time model is trained',
          selectedModelName: 'Gemma 2 2B Instruct',
        ),
        contains('does not store a training-cutoff date'),
      );
      expect(
        AssistantGroundedReply.tryHandle(prompt: 'what model are we using'),
        contains('No chat model is selected'),
      );
    });

    test('leaves greetings and calendar prompts for other handlers', () {
      expect(AssistantGroundedReply.tryHandle(prompt: 'hi'), isNull);
      expect(
        AssistantGroundedReply.tryHandle(prompt: 'list all events'),
        isNull,
      );
    });
  });
}
