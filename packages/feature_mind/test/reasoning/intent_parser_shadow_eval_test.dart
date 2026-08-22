import 'package:feature_mind/src/agent_chat/domain/services/intent_parser.dart';
import 'package:feature_mind/src/reasoning/chat_reasoning_request.dart';
import 'package:feature_mind/src/reasoning/reasoning_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'IntentParser leftovers hydrate only kinds Rust already understands',
    () {
      const leftovers = <String, String>{
        'I need to prepare for tomorrow.': 'conversation',
        'Why is the sky blue?': 'conversation',
        'Make me a 7 day vegetarian diet plan': 'skill',
        'Create a meal plan': 'skill',
        'plan my budget': 'navigation',
      };
      const allowed = {
        'calendar_retrieval',
        'time_query',
        'date_query',
        'play_media',
        'toggle_setting',
        'navigation',
        'planning',
        'skill',
        'diet',
        'summarization',
        'conversation',
      };
      leftovers.forEach((prompt, kind) {
        final parsed = IntentParser.parse(prompt);
        expect(reasoningIntentKind(parsed.type), kind, reason: prompt);
        expect(allowed, contains(kind), reason: prompt);
        expect(kind, isNot('diet.plan'));
      });
    },
  );

  test('diet leftover is skill.execute, not a diet domain', () {
    final parsed = IntentParser.parse('Make me a 7 day vegetarian diet plan');
    expect(parsed.type, IntentType.createDietPlan);
    expect(reasoningIntentKind(parsed.type), 'skill');
    expect(reasoningIntentKind(parsed.type), isNot('diet'));
  });

  test('plan my budget leftover stays navigation until classify wins', () {
    final parsed = IntentParser.parse('plan my budget');
    expect(parsed.type, IntentType.openBudget);
    expect(reasoningIntentKind(parsed.type), 'navigation');
  });

  test('shadow progress records a leftover mismatch without becoming a step', () {
    final fold = ReasoningStreamFold();
    fold.add(const MindReasoningStageChanged(MindReasoningStage.understanding));
    fold.add(
      const MindReasoningProgress(
        'shadow:navigation|general.navigate|planning|planning.create|classified|0',
      ),
    );
    fold.add(const MindReasoningProgress('level=Standard'));
    fold.add(
      const MindReasoningCompleted(
        answer: 'Split income and bills.',
        reasoningSummary: 'A budget plan.',
        level: MindReasoningLevel.standard,
      ),
    );

    expect(fold.shadowCompare, isNotNull);
    expect(fold.shadowCompare!.parserKind, 'navigation');
    expect(fold.shadowCompare!.parserCapability, 'general.navigate');
    expect(fold.shadowCompare!.classifiedKind, 'planning');
    expect(fold.shadowCompare!.classifiedCapability, 'planning.create');
    expect(fold.shadowCompare!.status, 'classified');
    expect(fold.shadowCompare!.capabilitiesMatch, isFalse);
    expect(fold.answer, 'Split income and bills.');
    expect(fold.steps, [
      const ReasoningProgressStep(label: 'Reading your request'),
    ]);
    expect(fold.steps.any((s) => s.label.startsWith('shadow:')), isFalse);
    expect(fold.steps.any((s) => s.label.contains('navigation')), isFalse);
  });

  test('underspecified prepare-for-tomorrow shadow still asks, not execute', () {
    final fold = ReasoningStreamFold();
    fold.add(
      const MindReasoningProgress(
        'shadow:conversation|general.chat|conversation|general.chat|needs_clarification|1',
      ),
    );
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
    expect(fold.shadowCompare!.capabilitiesMatch, isTrue);
    expect(fold.shadowCompare!.status, 'needs_clarification');
    expect(fold.shadowCompare!.classifiedCapability, isNot('diet.plan'));
    expect(fold.clarificationCandidates, isNotEmpty);
    expect(fold.steps, isEmpty);
  });

  test('sky blue leftover compares as general.chat', () {
    final parsed = IntentParser.parse('Why is the sky blue?');
    expect(parsed.type, IntentType.unknown);
    expect(reasoningIntentKind(parsed.type), 'conversation');
    final compare = parseShadowProgress(
      'shadow:conversation|general.chat|conversation|general.chat|classified|1',
    )!;
    expect(compare.parserKind, reasoningIntentKind(parsed.type));
    expect(compare.classifiedCapability, 'general.chat');
    expect(compare.capabilitiesMatch, isTrue);
  });
}
