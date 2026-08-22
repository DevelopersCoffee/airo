import 'package:feature_mind/src/agent_chat/data/services/assistant_chat_context_builder.dart';
import 'package:feature_mind/src/agent_chat/data/services/diet_plan_plugin_prompt.dart';
import 'package:feature_mind/src/agent_chat/data/services/gguf_instruct_prompt.dart';
import 'package:feature_mind/src/agent_chat/domain/services/agent_skill_orchestrator.dart';
import 'package:feature_mind/src/agent_chat/domain/services/intent_parser.dart';
import 'package:feature_mind/src/agent_chat/domain/services/tool_registry.dart';
import 'package:core_ai/core_ai.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/plugin_skill_fixture.dart';

final draftDietPlanSkill = loadPluginSkillFixture('draft-diet-plan');

/// Deterministic eval of the Assistant chip prompts plus the transcript
/// follow-ups that failed in the 0.5B Mind chat session.
void main() {
  final registry = ToolRegistry();

  const chipPrompts = <String>[
    'Help me think through a task',
    'What can you do in Airo?',
    'Check my schedule for today',
    'Remind me to take Minoxidil every 12 hours starting at 8am',
    'Split this ₹2400 bill with Asha, Ben and Chen',
    'Make me a 7 day diet plan',
    'Create a morning study routine for tomorrow',
    'Ask image about this receipt',
    'Open mobile actions',
    'Manage offline models',
    'I am bored, start chess',
  ];

  test('every Assistant chip prompt parses without throwing', () {
    for (final prompt in chipPrompts) {
      expect(() => IntentParser.parse(prompt), returnsNormally, reason: prompt);
      final gate = ChatTurnReliability.plan(
        userText: prompt,
        definition: AiroPromptRegistry.chatAssistant,
      );
      expect(gate.definition.qualifiedId, 'chat.assistant.v1');
      expect(gate.blocksInference, isFalse, reason: prompt);
      final live = ChatTurnReliability.plan(
        userText: prompt,
        systemPrompt: 'You are Airo. Be brief. Stay on the last user question.',
        definition: AiroPromptRegistry.chatAssistant,
      );
      expect(live.blocksInference, isFalse, reason: prompt);
      expect(live.gate.userMessage, isNot(contains('PD-')));
    }
  });

  test(
    'send-path live gate uses the compiled Airo prompt without blocking chips',
    () {
      const builder = AssistantChatContextBuilder();
      for (final prompt in chipPrompts) {
        final systemPrompt = builder.buildSystemPrompt(
          currentUserPrompt: prompt,
          compact: true,
          history: const [],
        );
        final live = ChatTurnReliability.plan(
          userText: prompt,
          systemPrompt: systemPrompt,
          definition: AiroPromptRegistry.chatAssistant,
        );
        expect(live.blocksInference, isFalse, reason: prompt);
        expect(live.gate.userMessage, isNot(contains('PD-')));
        expect(live.gate.userMessage, isNot(contains('PM-')));
      }
    },
  );

  test(
    'compiled JSON vs user markdown warns on send and still allows inference',
    () {
      const builder = AssistantChatContextBuilder();
      const userText = 'Output markdown only.';
      final systemPrompt = [
        builder.buildSystemPrompt(
          currentUserPrompt: userText,
          compact: true,
          history: const [],
        ),
        'Respond in JSON only.',
      ].join('\n\n');
      final live = ChatTurnReliability.plan(
        userText: userText,
        systemPrompt: systemPrompt,
        definition: AiroPromptRegistry.chatAssistant,
      );
      expect(live.blocksInference, isFalse);
      expect(live.gate.decision, PromptGateDecision.allow);
      expect(
        live.gate.warnings,
        contains(PromptDefect.spec003ConflictingInstructions),
      );
      expect(
        live.gate.defects,
        isNot(contains(PromptDefect.spec003ConflictingInstructions)),
      );
      expect(live.gate.userMessage, isEmpty);
      expect(live.gate.userMessage, isNot(contains('PD-')));
    },
  );

  test(
    'user-only format conflict still asks before the send-path model call',
    () {
      const builder = AssistantChatContextBuilder();
      const userText = 'Always return JSON. Explain this normally.';
      final live = ChatTurnReliability.plan(
        userText: userText,
        systemPrompt: builder.buildSystemPrompt(
          currentUserPrompt: userText,
          compact: true,
          history: const [],
        ),
        definition: AiroPromptRegistry.chatAssistant,
      );
      expect(live.blocksInference, isTrue);
      expect(live.gate.decision, PromptGateDecision.askUser);
      expect(live.gate.userMessage, contains('more detail'));
      expect(live.gate.userMessage, isNot(contains('PD-')));
    },
  );

  test('tool-backed chip prompts return a usable draft or route', () async {
    const toolBacked = [
      'Split this ₹2400 bill with Asha, Ben and Chen',
      'Create a morning study routine for tomorrow',
      'Ask image about this receipt',
      'Open mobile actions',
      'Manage offline models',
      'I am bored, start chess',
    ];

    for (final prompt in toolBacked) {
      final intent = IntentParser.parse(prompt);
      expect(intent.type, isNot(IntentType.unknown), reason: prompt);
      final result = await registry.executeIntent(intent);
      expect(result.isError, isFalse, reason: prompt);
      expect(result.message.trim(), isNotEmpty, reason: prompt);
    }
  });

  test('diet prompts are LLM plugin work, not a canned menu', () {
    expect(
      IntentParser.parse('Make me a 7 day vegetarian diet plan').type,
      IntentType.createDietPlan,
    );
    expect(IntentParser.parse('non veg only').type, IntentType.createDietPlan);
    expect(IntentParser.parse('veg only').type, IntentType.createDietPlan);

    expect(draftDietPlanSkill.isGenerativePlugin, isTrue);
    expect(draftDietPlanSkill.instructions, contains('stated constraints'));
    expect(
      draftDietPlanSkill.instructions.toLowerCase(),
      isNot(contains('oats')),
    );
    expect(
      draftDietPlanSkill.instructions.toLowerCase(),
      isNot(contains('chicken')),
    );
  });

  test('diet plugin playbook is injected for the chat model', () {
    const builder = AssistantChatContextBuilder();
    final prompt = builder.buildSystemPrompt(
      currentUserPrompt: 'Make me a 7 day vegetarian diet plan',
      compact: true,
      pluginPlaybooks: [
        '${draftDietPlanSkill.name}: ${draftDietPlanSkill.instructions}',
      ],
      history: const [],
    );

    expect(prompt, contains('Enabled plugins:'));
    expect(prompt, contains('Diet Plan:'));
    expect(prompt, contains('Do not invent a fixed menu from the app'));
    expect(prompt, contains('follow it fully'));
    expect(prompt, contains('Reply briefly unless an enabled plugin applies'));
  });

  test('hi and 2+2 stay free-form chat, not skill or diet intents', () {
    expect(IntentParser.parse('hi').type, IntentType.unknown);
    expect(IntentParser.parse('2+2').type, IntentType.unknown);
    expect(
      DietPlanPluginPrompt.applies(
        currentPrompt: 'hi',
        history: const [
          AssistantChatContextMessage(
            text: 'Make me a 7 day diet plan',
            isUser: true,
          ),
          AssistantChatContextMessage(
            text: 'Day 1: Breakfast — Oatmeal; lunch — Grilled chicken',
            isUser: false,
          ),
        ],
      ),
      isFalse,
    );
  });

  test('warming and catalog-missing copy never enter compact GGUF context', () {
    const builder = AssistantChatContextBuilder();
    final prompt = builder.buildSystemPrompt(
      currentUserPrompt: 'hi',
      compact: true,
      history: const [
        AssistantChatContextMessage(
          text:
              'You selected Qwen2.5 0.5B Instruct (Q4_K_M). Warming it on device before you can send.',
          isUser: false,
        ),
        AssistantChatContextMessage(text: 'hi', isUser: true),
      ],
    );

    expect(prompt, isNot(contains('Warming it on device')));
    expect(
      formatGgufInstructPrompt(
        prompt: 'hi',
        systemPrompt: prompt,
        family: ModelFamily.qwen,
      ),
      contains('<|im_start|>assistant'),
    );
  });

  test(
    'wraps Gemma instruct turns instead of concatenating system and user',
    () {
      final wrapped = formatGgufInstructPrompt(
        prompt: 'hi',
        systemPrompt: 'You are Airo.',
        family: ModelFamily.gemma,
      );
      expect(wrapped, contains('<start_of_turn>user'));
      expect(wrapped, contains('<start_of_turn>model'));
      expect(wrapped, isNot(contains('<|im_start|>')));
      expect(wrapped, isNot(contains('Everyday meal ideas')));
      expect(wrapped, contains('or repeat a previous reply'));
    },
  );

  test('prefills the Gemma model turn with a locked header', () {
    final wrapped = formatGgufInstructPrompt(
      prompt: 'write the plan',
      systemPrompt: 'You are Airo.',
      family: ModelFamily.gemma,
      assistantPrefill: "Here's a 3-day diet plan:\n\n",
    );
    expect(
      wrapped,
      endsWith("<start_of_turn>model\nHere's a 3-day diet plan:\n\n"),
    );
  });

  test('Llama uses Llama-3 headers; Qwen stays on ChatML', () {
    for (final family in [ModelFamily.llama, ModelFamily.qwen]) {
      final wrapped = formatGgufInstructPrompt(
        prompt: '2+2',
        systemPrompt: 'You are Airo.',
        family: family,
      );
      if (family == ModelFamily.qwen) {
        expect(wrapped, contains('<|im_start|>assistant'));
      } else {
        expect(wrapped, contains('<|start_header_id|>system'));
        expect(wrapped, contains('You are Airo.'));
        expect(wrapped, contains('2+2'));
        expect(wrapped, isNot(contains('<|im_start|>')));
      }
      expect(wrapped, isNot(contains('<start_of_turn>')));
    }
  });

  test(
    'skill.select and skill.next_action schemas parse registry fixtures',
    () {
      expect(AiroPromptRegistry.skillSelect.hasEvalSuite, isTrue);
      expect(AiroPromptRegistry.skillNextAction.hasEvalSuite, isTrue);
      expect(
        parseSelectedSkillId('{"skill_id":"read-calendar-events"}'),
        'read-calendar-events',
      );
      expect(parseSelectedSkillId('not json'), isNull);
      expect(
        parseSkillModelAction(
          '{"type":"tool_call","tool":"read_calendar_events","arguments":{}}',
        )?.tool,
        'read_calendar_events',
      );
      expect(
        parseSkillModelAction(
          '{"type":"final","message":"No events today."}',
        )?.message,
        'No events today.',
      );
    },
  );

  test('trims 0.5B transcript continuation after a short answer', () {
    expect(
      trimGgufRoleBleed(
        '+2=4\nAiro: Sure, I can help you with that. Ready to proceed?',
      ),
      '+2=4',
    );
  });

  test('trims Gemma role bleed, placeholders, and repeated lines', () {
    expect(
      trimGgufRoleBleed(
        'Hello! How can I assist you today? Airo: Hello! How can I assist you today?',
      ),
      'Hello! How can I assist you today?',
    );
    expect(
      trimGgufRoleBleed(
        'Hello!\n[Type your information here]\n[Type your information here]',
      ),
      'Hello!',
    );
    expect(
      trimGgufRoleBleed('Thanks.<end_of_turn><start_of_turn>user\nMore'),
      'Thanks.',
    );
    expect(
      trimGgufRoleBleed("I'm sorry, but I can't assist with that. </model>"),
      "I'm sorry, but I can't assist with that.",
    );
  });
}
