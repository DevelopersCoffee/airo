import 'package:core_ai/core_ai.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PromptInertiaGuard', () {
    const guard = PromptInertiaGuard.defaults;

    test('strips an earlier day-count from user history', () {
      final revised = guard.revise(
        history: const [
          Prompt.user('Make me a 7 day diet plan'),
          Prompt.assistant('Here is a 7-day diet plan.\nDay 1: oats'),
        ],
        currentUserMessage: 'for 3 days',
      );

      expect(revised[0].content, 'Make me a diet plan');
      expect(revised[1].content, contains('superseded'));
      expect(revised[1].content, isNot(contains('7-day')));
    });

    test('leaves history alone when the current turn has no scalar', () {
      final history = const [Prompt.user('Make me a 7 day diet plan')];
      expect(
        guard.revise(history: history, currentUserMessage: 'thanks'),
        history,
      );
    });

    test('keeps a matching day-count in earlier turns', () {
      final revised = guard.revise(
        history: const [Prompt.user('Make me a 3 day diet plan')],
        currentUserMessage: 'keep it 3 days',
      );
      expect(revised.single.content, 'Make me a 3 day diet plan');
    });
  });

  group('GbnfGrammar', () {
    test('forces the requested prefix as a GBNF root string', () {
      final grammar = GbnfGrammar.forcedPrefix("Here's a 3-day diet plan:\n");
      expect(grammar, startsWith('root ::= "'));
      expect(grammar, contains(r"Here's a 3-day diet plan:\n"));
      expect(grammar, contains('body ::= '));
    });

    test('escapes quotes inside the prefix', () {
      final grammar = GbnfGrammar.forcedPrefix('Say "hi"');
      expect(grammar, contains(r'Say \"hi\"'));
    });
  });

  group('GenerationConstraint', () {
    test('builds a prefix constraint with matching GBNF', () {
      final constraint = GenerationConstraint.forcedPrefix("3-Day Plan\n\n");
      expect(constraint.forcedPrefix, "3-Day Plan\n\n");
      expect(constraint.gbnf, GbnfGrammar.forcedPrefix("3-Day Plan\n\n"));
    });
  });
}
