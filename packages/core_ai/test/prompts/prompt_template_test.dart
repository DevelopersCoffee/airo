import 'package:core_ai/core_ai.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PromptTemplate', () {
    test('fill replaces variables correctly', () {
      const template = PromptTemplate(
        template: 'Hello {{name}}, you are {{age}} years old.',
        variables: ['name', 'age'],
      );

      final result = template.fill({'name': 'Alice', 'age': '30'});

      expect(result, 'Hello Alice, you are 30 years old.');
    });

    test('fill throws ArgumentError for missing variable', () {
      const template = PromptTemplate(
        template: 'Hello {{name}}',
        variables: ['name'],
      );

      expect(() => template.fill({}), throwsArgumentError);
    });

    test('validate returns true when all variables provided', () {
      const template = PromptTemplate(
        template: 'Hello {{name}}',
        variables: ['name'],
      );

      expect(template.validate({'name': 'Alice'}), isTrue);
    });

    test('validate returns false when variables missing', () {
      const template = PromptTemplate(
        template: 'Hello {{name}}',
        variables: ['name'],
      );

      expect(template.validate({}), isFalse);
    });

    test('getMissingVariables returns missing variables', () {
      const template = PromptTemplate(
        template: 'Hello {{name}}, {{greeting}}',
        variables: ['name', 'greeting'],
      );

      final missing = template.getMissingVariables({'name': 'Alice'});

      expect(missing, ['greeting']);
    });

    test('getMissingVariables returns empty list when all provided', () {
      const template = PromptTemplate(
        template: 'Hello {{name}}',
        variables: ['name'],
      );

      final missing = template.getMissingVariables({'name': 'Alice'});

      expect(missing, isEmpty);
    });
  });

  group('AiroPrompts', () {
    test('receiptParsing template has correct structure', () {
      const template = AiroPrompts.receiptParsing;

      expect(template.variables, contains('receipt_text'));
      expect(template.version, isNotEmpty);
      expect(template.template, contains('{{receipt_text}}'));
    });

    test('billSplit template has correct structure', () {
      const template = AiroPrompts.billSplit;

      expect(template.variables, containsAll(['items', 'participants']));
      expect(template.template, contains('{{items}}'));
      expect(template.template, contains('{{participants}}'));
    });

    test('receiptParsing can be filled', () {
      const template = AiroPrompts.receiptParsing;

      final result = template.fill({
        'receipt_text': 'Coffee \$5.00\nTotal: \$5.00',
      });

      expect(result, contains('Coffee'));
      expect(result, contains('5.00'));
    });
  });

  group('Prompt', () {
    test('system prompt has correct role', () {
      const prompt = Prompt.system('You are a helpful assistant');

      expect(prompt.role, PromptRole.system);
      expect(prompt.content, 'You are a helpful assistant');
    });

    test('user prompt has correct role', () {
      const prompt = Prompt.user('Hello');

      expect(prompt.role, PromptRole.user);
      expect(prompt.content, 'Hello');
    });

    test('assistant prompt has correct role', () {
      const prompt = Prompt.assistant('Hi there!');

      expect(prompt.role, PromptRole.assistant);
      expect(prompt.content, 'Hi there!');
    });

    test('toMap returns correct structure', () {
      const prompt = Prompt.user('Hello');
      final map = prompt.toMap();

      expect(map['role'], 'user');
      expect(map['content'], 'Hello');
    });

    test('equality works correctly', () {
      const prompt1 = Prompt.user('Hello');
      const prompt2 = Prompt.user('Hello');
      const prompt3 = Prompt.user('Hi');

      expect(prompt1, equals(prompt2));
      expect(prompt1, isNot(equals(prompt3)));
    });
  });

  group('TokenCounter', () {
    test('estimate returns reasonable token count', () {
      const text = 'Hello, this is a test message.';
      final tokens = TokenCounter.estimate(text);

      // ~4 chars per token, 30 chars -> ~8 tokens
      expect(tokens, greaterThan(0));
      expect(tokens, lessThan(text.length));
    });

    test('fitsInLimit returns true for short text', () {
      const text = 'Short';
      final fits = TokenCounter.fitsInLimit(text, 100);

      expect(fits, isTrue);
    });

    test('fitsInLimit returns false for long text', () {
      final text = 'x' * 10000;
      final fits = TokenCounter.fitsInLimit(text, 10);

      expect(fits, isFalse);
    });

    test('truncateToFit returns original text if within limit', () {
      const text = 'Short text';
      final result = TokenCounter.truncateToFit(text, 100);

      expect(result, text);
    });

    test('truncateToFit truncates long text', () {
      final text = 'word ' * 100;
      final result = TokenCounter.truncateToFit(text, 10);

      expect(result.length, lessThan(text.length));
      expect(result, endsWith('...'));
    });
  });
}
