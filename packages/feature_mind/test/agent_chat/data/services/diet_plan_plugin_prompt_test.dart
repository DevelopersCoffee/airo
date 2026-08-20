import 'package:feature_mind/src/agent_chat/data/services/assistant_chat_context_builder.dart';
import 'package:feature_mind/src/agent_chat/data/services/diet_plan_plugin_prompt.dart';
import 'package:feature_mind/src/agent_chat/domain/services/intent_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const history = [
    AssistantChatContextMessage(
      text: 'Make me a 7 day diet plan',
      isUser: true,
    ),
    AssistantChatContextMessage(
      text:
          'Day 1:\n- Breakfast: Oatmeal\n- Lunch: Grilled chicken salad\n'
          '- Dinner: Baked salmon',
      isUser: false,
    ),
    AssistantChatContextMessage(
      text: 'i want some indian menu only',
      isUser: true,
    ),
    AssistantChatContextMessage(
      text:
          'Day 1:\n- Breakfast: Oatmeal with mixed nuts\n'
          '- Lunch: Grilled chicken with naan and naan bread',
      isUser: false,
    ),
  ];

  test('restates user constraints and drops previous assistant menus', () {
    const current = 'veg only';
    expect(
      DietPlanPluginPrompt.applies(currentPrompt: current, history: history),
      isTrue,
    );

    final constraints = DietPlanPluginPrompt.userConstraintLines(
      currentPrompt: current,
      history: history,
    );
    expect(constraints, [
      'Make me a 7 day diet plan',
      'i want some indian menu only',
      'veg only',
    ]);

    final context = DietPlanPluginPrompt.contextHistory(
      currentPrompt: current,
      history: history,
    );
    expect(context, hasLength(2));
    expect(context.map((message) => message.text), isNot(contains('chicken')));
    expect(context.every((message) => message.isUser), isTrue);

    final prompt = DietPlanPluginPrompt.modelUserPrompt(
      currentPrompt: current,
      history: history,
    );
    expect(prompt, contains('7 day diet plan'));
    expect(prompt, contains('indian menu only'));
    expect(prompt, contains('veg only'));
    expect(prompt, contains('Stop after Day 7'));
    expect(prompt, isNot(contains('Oatmeal')));
    expect(prompt, isNot(contains('Grilled chicken')));
  });

  test('trims overflow days and retries meat after a veg constraint', () {
    const draft =
        'Day 1: poha\nDay 2: idli\nDay 7: dal\nDay 8: oatmeal with chicken';
    expect(
      DietPlanPluginPrompt.trimExtraDays(draft, 7),
      isNot(contains('Day 8')),
    );
    expect(
      DietPlanPluginPrompt.shouldRetryVegetarian(
        output: 'Day 1: grilled chicken with naan',
        constraints: const ['veg only'],
      ),
      isTrue,
    );
    expect(
      DietPlanPluginPrompt.shouldRetryVegetarian(
        output: 'Day 1: grilled chicken with naan',
        constraints: const ['Make me a 7 day diet plan'],
      ),
      isFalse,
    );
  });

  test('does not treat hi after a diet plan as another diet turn', () {
    expect(
      DietPlanPluginPrompt.applies(currentPrompt: 'hi', history: history),
      isFalse,
    );
    expect(
      DietPlanPluginPrompt.applies(currentPrompt: '2+2', history: history),
      isFalse,
    );
    expect(
      DietPlanPluginPrompt.userConstraintLines(
        currentPrompt: 'hi',
        history: history,
      ),
      isNot(contains('hi')),
    );

    final collapsed = DietPlanPluginPrompt.collapseAssistantDietDrafts(history);
    expect(
      collapsed
          .where((message) => !message.isUser)
          .map((message) => message.text),
      everyElement('Drafted a meal plan.'),
    );
  });

  test('continues a short draft when the user asks for the next day', () {
    expect(
      DietPlanPluginPrompt.applies(currentPrompt: 'next day', history: history),
      isTrue,
    );
    final prompt = DietPlanPluginPrompt.modelUserPrompt(
      currentPrompt: 'next day',
      history: history,
    );
    expect(prompt, contains('Continue the existing diet plan'));
    expect(prompt, contains('Write Day 2 through Day 7'));
    expect(prompt, contains('Grilled chicken'));
    expect(prompt, isNot(contains('Drafted a meal plan')));
    expect(
      DietPlanPluginPrompt.looksLikeModelRefusal(
        "I'm sorry, but I can't assist with that.",
      ),
      isTrue,
    );
  });

  test('later day counts override the first 7-day request', () {
    const history = [
      AssistantChatContextMessage(
        text: 'Make me a 7 day diet plan',
        isUser: true,
      ),
      AssistantChatContextMessage(text: 'veg only', isUser: true),
    ];
    final prompt = DietPlanPluginPrompt.modelUserPrompt(
      currentPrompt: 'give me 3 days only',
      history: history,
    );
    expect(prompt, contains('The latest day count is 3'));
    expect(
      DietPlanPluginPrompt.parseDayCount(
        'Make me a 7 day diet plan veg only give me 3 days only',
      ),
      3,
    );
  });

  test('parses veg only as a diet refinement', () {
    expect(IntentParser.parse('veg only').type, IntentType.createDietPlan);
    expect(
      IntentParser.parse('veg only').parameters['dietStyle'],
      'vegetarian',
    );
  });
}
