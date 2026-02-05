import 'package:core_ai/core_ai.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LLMJsonParser', () {
    group('parseObject', () {
      test('parses pure JSON', () {
        const response = '{"name": "test", "value": 42}';
        final result = LLMJsonParser.parseObject(response);

        expect(result.isSuccess, isTrue);
        expect(result.value['name'], 'test');
        expect(result.value['value'], 42);
      });

      test('parses JSON in markdown code block', () {
        const response = '''
Here is the result:
```json
{"name": "test", "value": 42}
```
''';
        final result = LLMJsonParser.parseObject(response);

        expect(result.isSuccess, isTrue);
        expect(result.value['name'], 'test');
      });

      test('parses JSON with surrounding text', () {
        const response = '''
Based on my analysis, here is the structured data:
{"items": [1, 2, 3], "total": 6}
I hope this helps!
''';
        final result = LLMJsonParser.parseObject(response);

        expect(result.isSuccess, isTrue);
        expect(result.value['items'], [1, 2, 3]);
        expect(result.value['total'], 6);
      });

      test('returns failure for invalid JSON', () {
        const response = '{not valid json}';
        final result = LLMJsonParser.parseObject(response);

        expect(result.isFailure, isTrue);
        expect(result.failure.message, contains('No JSON object found'));
      });

      test('returns failure for array instead of object', () {
        const response = '[1, 2, 3]';
        final result = LLMJsonParser.parseObject(response);

        expect(result.isFailure, isTrue);
        expect(result.failure.message, contains('not a JSON object'));
      });

      test('returns failure when no JSON found', () {
        const response = 'Just some plain text without any JSON.';
        final result = LLMJsonParser.parseObject(response);

        expect(result.isFailure, isTrue);
        expect(result.failure.message, contains('No JSON object found'));
      });
    });

    group('parseArray', () {
      test('parses JSON array', () {
        const response = '[1, 2, 3]';
        final result = LLMJsonParser.parseArray(response);

        expect(result.isSuccess, isTrue);
        expect(result.value, [1, 2, 3]);
      });

      test('parses array in code block', () {
        const response = '''
```json
["apple", "banana", "cherry"]
```
''';
        final result = LLMJsonParser.parseArray(response);

        expect(result.isSuccess, isTrue);
        expect(result.value, ['apple', 'banana', 'cherry']);
      });
    });

    group('parseWithSchema', () {
      test('parses and validates with required fields', () {
        const response = '{"name": "Test", "amount": 100}';
        final result = LLMJsonParser.parseWithSchema<Map<String, dynamic>>(
          text: response,
          fromJson: (json) => json,
          requiredFields: ['name', 'amount'],
        );

        expect(result.isSuccess, isTrue);
        expect(result.value['name'], 'Test');
      });

      test('returns failure for missing required fields', () {
        const response = '{"name": "Test"}';
        final result = LLMJsonParser.parseWithSchema<Map<String, dynamic>>(
          text: response,
          fromJson: (json) => json,
          requiredFields: ['name', 'amount'],
        );

        expect(result.isFailure, isTrue);
        expect(result.failure.message, contains('amount'));
      });
    });
  });

  group('AiroParsers', () {
    group('parseReceipt', () {
      test('parses valid receipt response', () {
        const response = '''
```json
{
  "vendor": "Coffee Shop",
  "items": [
    {"name": "Latte", "price": 5.50, "quantity": 2},
    {"name": "Muffin", "price": 3.00}
  ],
  "subtotal": 14.00,
  "tax": 1.40,
  "total": 15.40
}
```
''';
        final result = AiroParsers.parseReceipt(response);

        expect(result.isSuccess, isTrue);
        expect(result.value.vendor, 'Coffee Shop');
        expect(result.value.items, hasLength(2));
        expect(result.value.items[0].name, 'Latte');
        expect(result.value.items[0].price, 5.50);
        expect(result.value.items[0].quantity, 2);
        expect(result.value.total, 15.40);
      });
    });

    group('parseBillSplit', () {
      test('parses valid bill split response', () {
        const response = '''
{
  "splits": [
    {"name": "Alice", "amount": 25.00, "items": ["Pizza"]},
    {"name": "Bob", "amount": 15.00, "items": ["Salad"]}
  ],
  "totalAmount": 40.00
}
''';
        final result = AiroParsers.parseBillSplit(response);

        expect(result.isSuccess, isTrue);
        expect(result.value.splits, hasLength(2));
        expect(result.value.splits[0].name, 'Alice');
        expect(result.value.splits[0].amount, 25.00);
        expect(result.value.totalAmount, 40.00);
      });
    });
  });
}
