import 'package:core_ai/core_ai.dart';
import 'package:feature_mind/src/addons/built_in_addon_registry.dart';
import 'package:feature_mind/src/addons/draft_diet_plan/draft_diet_plan_adapter.dart';
import 'package:feature_mind/src/agent_chat/data/services/assistant_chat_context_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('built-in registry routes diet plan through coordinator', () {
    final builtIn = BuiltInAddonRegistry.create();
    final history = [
      const AssistantChatContextMessage(
        text: 'Make me a 7 day vegetarian diet plan',
        isUser: true,
      ),
    ];
    final plan = builtIn.coordinator.planFor(
      currentPrompt: 'Make me a 7 day vegetarian diet plan',
      history: history,
    );

    expect(plan, isNotNull);
    expect(plan!.identity.id.value, DraftDietPlanAdapter.addonId);
    expect(plan.prompt.userPrompt, contains('vegetarian'));
    expect(plan.maxOutputTokens, isNotNull);
    expect(plan.constraint?.forcedPrefix, contains('7-day'));
  });

  test('coordinator reviews diet output and requests one retry', () {
    final builtIn = BuiltInAddonRegistry.create();
    final history = [
      const AssistantChatContextMessage(
        text: 'Make me a 7 day vegetarian diet plan',
        isUser: true,
      ),
    ];
    final plan = builtIn.coordinator.planFor(
      currentPrompt: 'Make me a 7 day vegetarian diet plan',
      history: history,
    );
    expect(plan, isNotNull);

    const weakDraft = "Here's a 7-day diet plan:\n\nDay 1: chicken curry";
    final firstReview = builtIn.coordinator.reviewOutput(
      plan: plan!,
      output: weakDraft,
      alreadyRetried: false,
    );
    expect(firstReview.shouldRetry, isTrue);

    final retryReview = builtIn.coordinator.reviewOutput(
      plan: plan,
      output: weakDraft,
      alreadyRetried: true,
    );
    expect(retryReview.shouldRetry, isFalse);
  });

  test('coordinator collapses thread history through diet adapter', () {
    final builtIn = BuiltInAddonRegistry.create();
    final history = [
      const AssistantChatContextMessage(
        text: 'Make me a 7 day vegetarian diet plan',
        isUser: true,
      ),
      const AssistantChatContextMessage(
        text: "Here's a 7-day diet plan:\n\nDay 1\nBreakfast: oats\nLunch: salad",
        isUser: false,
      ),
      const AssistantChatContextMessage(text: 'next day', isUser: true),
    ];
    final collapsed = builtIn.coordinator.collapseThreadHistory(history);
    expect(collapsed[1].text, 'Drafted a meal plan.');
  });

  test('draft diet adapter rejects unsafe requests with safe copy', () {
    final adapter = DraftDietPlanAdapter();
    const prompt = 'I need a strict 500 calorie fasting diet plan';
    final conversation = AddonConversation(
      currentPrompt: prompt,
      history: [
        const AddonConversationMessage(text: prompt, isUser: true),
      ],
    );
    expect(adapter.accepts(conversation), isTrue);
    final evaluation = adapter.evaluate(
      conversation,
      'Sure, here is your plan.',
    );
    expect(evaluation.kind, AddonEvaluationKind.invalid);
    expect(evaluation.safeCopy, contains('doctor'));
  });
}
