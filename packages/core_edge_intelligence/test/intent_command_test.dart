import 'dart:convert';
import 'dart:io';

import 'package:core_edge_intelligence/core_edge_intelligence.dart';
import 'package:test/test.dart';

void main() {
  test('execution result exposes immutable media identifiers', () {
    final result = IntentExecutionCompleted(resultIds: const ['one', 'two']);

    expect(result.resultCount, 2);
    expect(result.resultIds, ['one', 'two']);
    expect(() => result.resultIds.add('three'), throwsUnsupportedError);
  });

  group('IntentCommand v1', () {
    test('round-trips every intent and typed contract branch', () {
      for (final intent in MediaIntent.values) {
        final command = IntentCommand(
          intent: intent,
          entities: const [
            IntentEntityValue(type: IntentEntityType.genre, value: 'news'),
          ],
          filters: const [
            IntentFilterPredicate(
              field: IntentFilterField.language,
              operator: IntentFilterOperator.equals,
              value: 'hi',
            ),
            IntentFilterPredicate(
              field: IntentFilterField.live,
              operator: IntentFilterOperator.notEquals,
              value: false,
            ),
            IntentFilterPredicate(
              field: IntentFilterField.year,
              operator: IntentFilterOperator.greaterThanOrEqual,
              value: 2020,
            ),
          ],
          sort: const IntentFieldSort(
            field: IntentFilterField.title,
            direction: IntentSortDirection.ascending,
          ),
          confidence: 0.94,
        );

        final encoded = jsonEncode(command.toJson());
        final decoded = jsonDecode(encoded) as Map<String, Object?>;
        final reparsed = IntentCommand.fromJson(decoded);

        expect(reparsed.intent, intent);
        expect(reparsed.entities.single.type, IntentEntityType.genre);
        expect(reparsed.entities.single.value, 'news');
        expect(reparsed.filters, hasLength(3));
        expect(
          reparsed.filters.map((filter) => filter.operator),
          containsAll([
            IntentFilterOperator.equals,
            IntentFilterOperator.notEquals,
            IntentFilterOperator.greaterThanOrEqual,
          ]),
        );
        expect(reparsed.sort?.field, IntentFilterField.title);
        expect(reparsed.sort?.direction, IntentSortDirection.ascending);
        expect(reparsed.confidence, 0.94);
        expect(reparsed.toJson(), command.toJson());
      }
    });

    test('accepts empty lists, null sort, and confidence boundaries', () {
      for (final confidence in [0.0, 1.0]) {
        final validation = IntentCommand.validateJson({
          'intent': 'browse',
          'entities': <Object?>[],
          'filters': <Object?>[],
          'sort': null,
          'confidence': confidence,
        });

        expect(validation, isA<ValidIntentCommand>());
        expect(validation.isValid, isTrue);
        expect((validation as ValidIntentCommand).command.sort, isNull);
      }
    });

    test('rejects a non-object root', () {
      final validation = IntentCommand.validateJson(<Object?>[]);

      expectIssue(
        validation,
        path: r'$',
        code: IntentValidationCode.invalidType,
      );
    });

    test('rejects missing and unknown root fields', () {
      final validation = IntentCommand.validateJson({
        'intent': 'search',
        'entities': <Object?>[],
        'filters': <Object?>[],
        'confidence': 0.5,
        'secret': 'must-not-cross',
      });

      expectIssue(
        validation,
        path: r'$.sort',
        code: IntentValidationCode.missingField,
      );
      expectIssue(
        validation,
        path: r'$.secret',
        code: IntentValidationCode.unknownField,
      );
    });

    test('rejects unknown intent and invalid collection types', () {
      final validation = IntentCommand.validateJson({
        'intent': 'delete_everything',
        'entities': 'news',
        'filters': false,
        'sort': null,
        'confidence': 'high',
      });

      expectIssue(validation, path: r'$.intent');
      expectIssue(validation, path: r'$.entities');
      expectIssue(validation, path: r'$.filters');
      expectIssue(validation, path: r'$.confidence');
    });

    test('rejects malformed, unknown, and duplicate entities', () {
      final validation = IntentCommand.validateJson({
        'intent': 'search',
        'entities': [
          'news',
          {'type': 'unknown', 'value': ''},
          {'type': 'genre', 'value': 'news', 'extra': true},
          {'type': 'genre', 'value': 'news'},
        ],
        'filters': <Object?>[],
        'sort': null,
        'confidence': 0.5,
      });

      expectIssue(validation, path: r'$.entities[0]');
      expectIssue(validation, path: r'$.entities[1].type');
      expectIssue(validation, path: r'$.entities[1].value');
      expectIssue(validation, path: r'$.entities[2].extra');
      expectIssue(
        validation,
        path: r'$.entities[3]',
        code: IntentValidationCode.duplicateValue,
      );
    });

    test('rejects malformed filter fields, operators, and values', () {
      final validation = IntentCommand.validateJson({
        'intent': 'search',
        'entities': <Object?>[],
        'filters': [
          'language=hi',
          {
            'field': 'unknown',
            'operator': 'around',
            'value': <String>['hi'],
            'extra': true,
          },
        ],
        'sort': null,
        'confidence': 0.5,
      });

      expectIssue(validation, path: r'$.filters[0]');
      expectIssue(validation, path: r'$.filters[1].field');
      expectIssue(validation, path: r'$.filters[1].operator');
      expectIssue(validation, path: r'$.filters[1].value');
      expectIssue(validation, path: r'$.filters[1].extra');
    });

    test('rejects malformed sort and out-of-range confidence', () {
      final wrongSortType = validJson()
        ..['sort'] = 'recent'
        ..['confidence'] = double.nan;
      final wrongSortValues = validJson()
        ..['sort'] = {
          'field': 'unknown',
          'direction': 'sideways',
          'extra': true,
        }
        ..['confidence'] = 1.1;

      expectIssue(IntentCommand.validateJson(wrongSortType), path: r'$.sort');
      final validation = IntentCommand.validateJson(wrongSortValues);
      expectIssue(validation, path: r'$.sort.field');
      expectIssue(validation, path: r'$.sort.direction');
      expectIssue(validation, path: r'$.sort.extra');
      expectIssue(validation, path: r'$.confidence');
    });

    test('fromJson fails closed with path-specific FormatException', () {
      expect(
        () => IntentCommand.fromJson(validJson()..['intent'] = 'unknown'),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains(r'$.intent'),
          ),
        ),
      );
    });

    test('vendored schema declares the same public enums', () {
      final schema =
          jsonDecode(File(intentCommandSchemaAsset).readAsStringSync())
              as Map<String, Object?>;
      final properties = schema['properties'] as Map<String, Object?>;
      final intent = properties['intent'] as Map<String, Object?>;

      expect(intent['enum'], MediaIntent.values.map((value) => value.name));
      expect(intentCommandSchemaVersion, '1.0.0');
    });
  });

  test('executor result types do not expose player-specific state', () async {
    final executor = _FakeIntentExecutor();
    final result = await executor.execute(IntentCommand.fromJson(validJson()));

    expect(result, isA<IntentExecutionCompleted>());
    expect((result as IntentExecutionCompleted).resultCount, 1);
    expect(
      const IntentExecutionRejected(code: 'unsupported', message: 'No match'),
      isA<IntentExecutionResult>(),
    );
    expect(
      const IntentExecutionFailed(code: 'engine_unavailable'),
      isA<IntentExecutionResult>(),
    );
  });
}

Map<String, Object?> validJson() => {
  'intent': 'search',
  'entities': <Object?>[],
  'filters': <Object?>[],
  'sort': null,
  'confidence': 0.5,
};

void expectIssue(
  IntentCommandValidation validation, {
  required String path,
  IntentValidationCode? code,
}) {
  expect(validation, isA<InvalidIntentCommand>());
  expect(validation.isValid, isFalse);
  final issues = (validation as InvalidIntentCommand).issues;
  expect(
    issues,
    contains(
      isA<IntentValidationIssue>()
          .having((issue) => issue.path, 'path', path)
          .having((issue) => issue.code, 'code', code ?? anything),
    ),
  );
}

final class _FakeIntentExecutor implements IntentExecutor {
  @override
  Future<IntentExecutionResult> execute(IntentCommand command) async {
    return IntentExecutionCompleted(resultIds: const ['result']);
  }
}
