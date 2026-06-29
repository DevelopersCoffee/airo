import 'package:airo_app/features/agent_chat/data/services/assistant_chat_context_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AssistantChatContextBuilder', () {
    const builder = AssistantChatContextBuilder();

    test('injects stable Airo product context for fresh chats', () {
      final prompt = builder.buildSystemPrompt(
        currentUserPrompt: 'what does airo do',
        history: const [],
      );

      expect(
        prompt,
        contains('You are Airo, the assistant inside the Airo app.'),
      );
      expect(prompt, contains('local-first AI assistant'));
      expect(
        prompt,
        contains('avoid acting like you have never heard of Airo'),
      );
    });

    test('includes recent conversation context for continuity', () {
      final prompt = builder.buildSystemPrompt(
        currentUserPrompt: 'what can it do for reminders?',
        history: const [
          AssistantChatContextMessage(text: 'What does Airo do?', isUser: true),
          AssistantChatContextMessage(
            text:
                'Airo can help with planning, reminders, and opening app features.',
            isUser: false,
          ),
        ],
      );

      expect(prompt, contains('Recent conversation:'));
      expect(prompt, contains('User: What does Airo do?'));
      expect(
        prompt,
        contains(
          'Airo: Airo can help with planning, reminders, and opening app features.',
        ),
      );
    });
  });
}
