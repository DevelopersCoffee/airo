import 'package:feature_mind/src/agent_chat/data/services/assistant_chat_context_builder.dart';
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

    test('excludes operational status bubbles from model context', () {
      final prompt = builder.buildSystemPrompt(
        currentUserPrompt: 'hi',
        history: const [
          AssistantChatContextMessage(
            text:
                'You selected Qwen2.5 0.5B Instruct (Q4_K_M). Warming it on device before you can send.',
            isUser: false,
          ),
          AssistantChatContextMessage(
            text:
                'The selected offline package is no longer in the catalog. Open Project setup and choose another model.',
            isUser: false,
          ),
        ],
      );

      expect(prompt, isNot(contains('Warming it on device')));
      expect(prompt, isNot(contains('no longer in the catalog')));
    });

    test('compact mode keeps a short system prompt', () {
      final prompt = builder.buildSystemPrompt(
        currentUserPrompt: '2+2',
        compact: true,
        history: const [],
      );

      expect(prompt, contains('Reply briefly'));
      expect(prompt, isNot(contains('split bills')));
    });

    test(
      'injects generative plugin playbooks without forcing brief replies',
      () {
        final prompt = builder.buildSystemPrompt(
          currentUserPrompt: 'Make me a 7 day vegetarian diet plan',
          compact: true,
          pluginPlaybooks: const [
            'Diet Plan: write the plan from the user\'s stated constraints.',
          ],
          history: const [],
        );

        expect(prompt, contains('Enabled plugins:'));
        expect(prompt, contains('Diet Plan:'));
        expect(prompt, contains('follow it fully'));
        expect(
          prompt,
          contains('Reply briefly unless an enabled plugin applies'),
        );
      },
    );

    test('pinned persona replaces generic Airo voice', () {
      final prompt = builder.buildSystemPrompt(
        currentUserPrompt: 'Draft a lesson on fractions',
        history: const [],
        pluginPlaybooks: const ['Lesson Planning: Suggest a lesson outline.'],
        pinnedPersonaIdentity:
            'You are Lesson Planning, a private on-device Airo assistant.',
      );

      expect(prompt, contains('You are Lesson Planning'));
      expect(prompt, contains('Suggest a lesson outline'));
      expect(prompt, contains('Do not switch roles'));
      expect(prompt, isNot(contains('You are Airo, the assistant inside')));
      expect(prompt, isNot(contains('Enabled plugins:')));
    });

    test('excludes the in-flight user prompt from recent context', () {
      final prompt = builder.buildSystemPrompt(
        currentUserPrompt: 'What can Airo do for reminders?',
        history: const [
          AssistantChatContextMessage(text: 'What does Airo do?', isUser: true),
          AssistantChatContextMessage(
            text: 'Airo helps with planning and app workflows.',
            isUser: false,
          ),
          AssistantChatContextMessage(
            text: '  what   can airo do for reminders?  ',
            isUser: true,
          ),
        ],
      );

      expect(prompt, contains('User: What does Airo do?'));
      expect(
        prompt,
        contains('Airo: Airo helps with planning and app workflows.'),
      );
      expect(
        prompt,
        isNot(contains('User: what   can airo do for reminders?')),
      );
    });

    test('drops unsolicited meal-ideas pitches from later turns', () {
      final prompt = builder.buildSystemPrompt(
        currentUserPrompt: 'what model are we using',
        history: const [
          AssistantChatContextMessage(text: 'hi', isUser: true),
          AssistantChatContextMessage(
            text:
                'Hey there! I can help you brainstorm some healthy and delicious meal ideas. What kind of meals are you looking for?',
            isUser: false,
          ),
        ],
      );

      expect(prompt, isNot(contains('healthy and delicious meal')));
      expect(prompt, contains('Do not repeat a previous greeting'));
    });

    test('rebuildForBudget keeps identity and drops older history', () {
      const longHistory = [
        AssistantChatContextMessage(text: 'first', isUser: true),
        AssistantChatContextMessage(text: 'ok', isUser: false),
        AssistantChatContextMessage(text: 'second', isUser: true),
        AssistantChatContextMessage(text: 'sure', isUser: false),
        AssistantChatContextMessage(text: 'third', isUser: true),
        AssistantChatContextMessage(text: 'done', isUser: false),
      ];
      final full = builder.buildSystemPrompt(
        currentUserPrompt: 'and now',
        history: longHistory,
      );
      final rebuilt = builder.rebuildForBudget().buildSystemPrompt(
        currentUserPrompt: 'and now',
        compact: true,
        history: longHistory,
      );

      expect(full, contains('User: first'));
      expect(rebuilt, isNot(contains('User: first')));
      expect(rebuilt, contains('User: third'));
      expect(rebuilt.length, lessThan(full.length));
    });
  });
}
