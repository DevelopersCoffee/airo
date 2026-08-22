import 'package:core_ai/core_ai.dart';
import 'package:feature_mind/src/addons/draft_diet_plan/draft_diet_plan_adapter.dart';
import 'package:feature_mind/src/agent_chat/data/services/assistant_chat_context_builder.dart';
import 'package:feature_mind/src/agent_chat/data/services/diet_plan_plugin_prompt.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('adapter mirrors DietPlanPluginPrompt routing', () {
    final adapter = DraftDietPlanAdapter();
    final history = [
      const AddonConversationMessage(
        text: 'Make me a 7 day vegetarian diet plan',
        isUser: true,
      ),
    ];
    final conversation = AddonConversation(
      currentPrompt: 'Make me a 7 day vegetarian diet plan',
      history: history,
    );
    final assistantHistory = [
      for (final message in history)
        AssistantChatContextMessage(
          text: message.text,
          isUser: message.isUser,
        ),
    ];

    expect(
      adapter.accepts(conversation),
      DietPlanPluginPrompt.applies(
        currentPrompt: conversation.currentPrompt,
        history: assistantHistory,
      ),
    );

    final prompt = adapter.buildPrompt(conversation);
    expect(
      prompt.userPrompt,
      DietPlanPluginPrompt.modelUserPrompt(
        currentPrompt: conversation.currentPrompt,
        history: assistantHistory,
      ),
    );
  });

  test('adapter supplies reasoning documents from constraints', () {
    final adapter = DraftDietPlanAdapter();
    final conversation = AddonConversation(
      currentPrompt: '7 day veg only',
      history: [
        const AddonConversationMessage(text: '7 day veg only', isUser: true),
      ],
    );
    final docs = adapter.reasoningDocuments(conversation);
    expect(docs, hasLength(1));
    expect(docs.single.source, 'diet_constraints');
    expect(docs.single.text.toLowerCase(), contains('veg'));
  });
}
