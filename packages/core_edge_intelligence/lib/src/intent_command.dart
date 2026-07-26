typedef IntentJson = Map<String, Object?>;

const String intentCommandSchemaVersion = '1.0.0';
const String intentCommandSchemaAsset = 'schemas/intent-command/v1/schema.json';

enum MediaIntent {
  browse,
  play,
  resume,
  similar,
  search;

  static MediaIntent? tryParse(Object? value) {
    if (value is! String) return null;
    for (final candidate in values) {
      if (candidate.name == value) return candidate;
    }
    return null;
  }
}

enum IntentEntityType {
  title,
  alias,
  genre,
  language,
  country,
  provider,
  tag,
  actor,
  director,
  studio,
  collection;

  static IntentEntityType? tryParse(Object? value) {
    if (value is! String) return null;
    for (final candidate in values) {
      if (candidate.name == value) return candidate;
    }
    return null;
  }
}

/// A structured entity extracted from an utterance.
sealed class IntentEntity {
  const IntentEntity();

  IntentEntityType get type;
  String get value;

  IntentJson toJson();
}

final class IntentEntityValue extends IntentEntity {
  const IntentEntityValue({required this.type, required this.value});

  @override
  final IntentEntityType type;

  @override
  final String value;

  @override
  IntentJson toJson() => {'type': type.name, 'value': value};
}

enum IntentFilterField {
  title,
  alias,
  genre,
  language,
  country,
  provider,
  tag,
  actor,
  director,
  studio,
  collection,
  live,
  favorite,
  year,
  durationSeconds;

  static IntentFilterField? tryParse(Object? value) {
    if (value is! String) return null;
    for (final candidate in values) {
      if (candidate.name == value) return candidate;
    }
    return null;
  }
}

enum IntentFilterOperator {
  equals,
  notEquals,
  contains,
  greaterThan,
  greaterThanOrEqual,
  lessThan,
  lessThanOrEqual;

  static IntentFilterOperator? tryParse(Object? value) {
    if (value is! String) return null;
    for (final candidate in values) {
      if (candidate.name == value) return candidate;
    }
    return null;
  }
}

/// A typed predicate applied by the media engine.
sealed class IntentFilter {
  const IntentFilter();

  IntentFilterField get field;
  IntentFilterOperator get operator;
  Object? get value;

  IntentJson toJson();
}

final class IntentFilterPredicate extends IntentFilter {
  const IntentFilterPredicate({
    required this.field,
    required this.operator,
    required this.value,
  }) : assert(
         value == null || value is String || value is num || value is bool,
         'Intent filter values must be JSON scalars',
       );

  @override
  final IntentFilterField field;

  @override
  final IntentFilterOperator operator;

  @override
  final Object? value;

  @override
  IntentJson toJson() => {
    'field': field.name,
    'operator': operator.name,
    'value': value,
  };
}

enum IntentSortDirection { ascending, descending }

/// A stable sort requested by the intelligence layer.
sealed class IntentSort {
  const IntentSort();

  IntentFilterField get field;
  IntentSortDirection get direction;

  IntentJson toJson();
}

final class IntentFieldSort extends IntentSort {
  const IntentFieldSort({required this.field, required this.direction});

  @override
  final IntentFilterField field;

  @override
  final IntentSortDirection direction;

  @override
  IntentJson toJson() => {'field': field.name, 'direction': direction.name};
}

final class IntentCommand {
  IntentCommand({
    required this.intent,
    Iterable<IntentEntity> entities = const [],
    Iterable<IntentFilter> filters = const [],
    required this.sort,
    required this.confidence,
  }) : assert(
         confidence >= 0 && confidence <= 1,
         'confidence must be between 0 and 1',
       ),
       entities = List.unmodifiable(entities),
       filters = List.unmodifiable(filters);

  final MediaIntent intent;
  final List<IntentEntity> entities;
  final List<IntentFilter> filters;
  final IntentSort? sort;
  final double confidence;

  IntentJson toJson() => {
    'intent': intent.name,
    'entities': entities.map((entity) => entity.toJson()).toList(),
    'filters': filters.map((filter) => filter.toJson()).toList(),
    'sort': sort?.toJson(),
    'confidence': confidence,
  };

  static IntentCommandValidation validateJson(Object? json) =>
      _IntentCommandParser(json).parse();

  static IntentCommand fromJson(IntentJson json) {
    final validation = validateJson(json);
    return switch (validation) {
      ValidIntentCommand(:final command) => command,
      InvalidIntentCommand(:final issues) => throw FormatException(
        issues.map((issue) => '${issue.path}: ${issue.message}').join('; '),
      ),
    };
  }
}

enum IntentValidationCode {
  invalidType,
  missingField,
  unknownField,
  invalidValue,
  duplicateValue,
}

final class IntentValidationIssue {
  const IntentValidationIssue({
    required this.path,
    required this.code,
    required this.message,
  });

  final String path;
  final IntentValidationCode code;
  final String message;
}

sealed class IntentCommandValidation {
  const IntentCommandValidation();

  bool get isValid;
}

final class ValidIntentCommand extends IntentCommandValidation {
  const ValidIntentCommand(this.command);

  final IntentCommand command;

  @override
  bool get isValid => true;
}

final class InvalidIntentCommand extends IntentCommandValidation {
  InvalidIntentCommand(Iterable<IntentValidationIssue> issues)
    : issues = List.unmodifiable(issues);

  final List<IntentValidationIssue> issues;

  @override
  bool get isValid => false;
}

final class _IntentCommandParser {
  _IntentCommandParser(this.input);

  static const _rootFields = {
    'intent',
    'entities',
    'filters',
    'sort',
    'confidence',
  };
  static const _entityFields = {'type', 'value'};
  static const _filterFields = {'field', 'operator', 'value'};
  static const _sortFields = {'field', 'direction'};

  final Object? input;
  final List<IntentValidationIssue> _issues = [];

  IntentCommandValidation parse() {
    if (input is! Map<String, Object?>) {
      _add(r'$', IntentValidationCode.invalidType, 'must be an object');
      return InvalidIntentCommand(_issues);
    }
    final json = input! as Map<String, Object?>;
    _checkFields(json, _rootFields, r'$');

    final intent = MediaIntent.tryParse(json['intent']);
    if (intent == null && json.containsKey('intent')) {
      _add(
        r'$.intent',
        IntentValidationCode.invalidValue,
        'must be one of ${MediaIntent.values.map((value) => value.name).join(', ')}',
      );
    }
    final entities = _parseEntities(json['entities']);
    final filters = _parseFilters(json['filters']);
    final sort = _parseSort(json['sort'], isPresent: json.containsKey('sort'));
    final confidenceValue = json['confidence'];
    double? confidence;
    if (confidenceValue is num) {
      confidence = confidenceValue.toDouble();
      if (!confidence.isFinite || confidence < 0 || confidence > 1) {
        _add(
          r'$.confidence',
          IntentValidationCode.invalidValue,
          'must be a finite number between 0 and 1',
        );
      }
    } else if (json.containsKey('confidence')) {
      _add(
        r'$.confidence',
        IntentValidationCode.invalidType,
        'must be a number',
      );
    }

    if (_issues.isNotEmpty ||
        intent == null ||
        entities == null ||
        filters == null ||
        confidence == null) {
      return InvalidIntentCommand(_issues);
    }
    return ValidIntentCommand(
      IntentCommand(
        intent: intent,
        entities: entities,
        filters: filters,
        sort: sort,
        confidence: confidence,
      ),
    );
  }

  List<IntentEntity>? _parseEntities(Object? value) {
    if (value is! List<Object?>) {
      if (value != null) {
        _add(
          r'$.entities',
          IntentValidationCode.invalidType,
          'must be an array',
        );
      }
      return null;
    }
    final result = <IntentEntity>[];
    final seen = <String>{};
    for (var index = 0; index < value.length; index++) {
      final path = '\$.entities[$index]';
      final item = value[index];
      if (item is! Map<String, Object?>) {
        _add(path, IntentValidationCode.invalidType, 'must be an object');
        continue;
      }
      _checkFields(item, _entityFields, path);
      final type = IntentEntityType.tryParse(item['type']);
      final entityValue = item['value'];
      if (type == null && item.containsKey('type')) {
        _add(
          '$path.type',
          IntentValidationCode.invalidValue,
          'has an unknown entity type',
        );
      }
      if (entityValue is! String || entityValue.trim().isEmpty) {
        _add(
          '$path.value',
          entityValue is String
              ? IntentValidationCode.invalidValue
              : IntentValidationCode.invalidType,
          'must be a non-empty string',
        );
      }
      if (type != null &&
          entityValue is String &&
          entityValue.trim().isNotEmpty) {
        final normalized = '${type.name}\u0000${entityValue.trim()}';
        if (!seen.add(normalized)) {
          _add(
            path,
            IntentValidationCode.duplicateValue,
            'duplicates an earlier entity',
          );
        } else {
          result.add(IntentEntityValue(type: type, value: entityValue.trim()));
        }
      }
    }
    return result;
  }

  List<IntentFilter>? _parseFilters(Object? value) {
    if (value is! List<Object?>) {
      if (value != null) {
        _add(
          r'$.filters',
          IntentValidationCode.invalidType,
          'must be an array',
        );
      }
      return null;
    }
    final result = <IntentFilter>[];
    for (var index = 0; index < value.length; index++) {
      final path = '\$.filters[$index]';
      final item = value[index];
      if (item is! Map<String, Object?>) {
        _add(path, IntentValidationCode.invalidType, 'must be an object');
        continue;
      }
      _checkFields(item, _filterFields, path);
      final field = IntentFilterField.tryParse(item['field']);
      final operator = IntentFilterOperator.tryParse(item['operator']);
      final filterValue = item['value'];
      if (field == null && item.containsKey('field')) {
        _add(
          '$path.field',
          IntentValidationCode.invalidValue,
          'has an unknown filter field',
        );
      }
      if (operator == null && item.containsKey('operator')) {
        _add(
          '$path.operator',
          IntentValidationCode.invalidValue,
          'has an unknown filter operator',
        );
      }
      if (!_isJsonScalar(filterValue)) {
        _add(
          '$path.value',
          IntentValidationCode.invalidType,
          'must be a string, number, boolean, or null',
        );
      }
      if (field != null && operator != null && _isJsonScalar(filterValue)) {
        result.add(
          IntentFilterPredicate(
            field: field,
            operator: operator,
            value: filterValue,
          ),
        );
      }
    }
    return result;
  }

  IntentSort? _parseSort(Object? value, {required bool isPresent}) {
    if (!isPresent) return null;
    if (value == null) return null;
    if (value is! Map<String, Object?>) {
      _add(
        r'$.sort',
        IntentValidationCode.invalidType,
        'must be an object or null',
      );
      return null;
    }
    _checkFields(value, _sortFields, r'$.sort');
    final field = IntentFilterField.tryParse(value['field']);
    final direction = _parseSortDirection(value['direction']);
    if (field == null && value.containsKey('field')) {
      _add(
        r'$.sort.field',
        IntentValidationCode.invalidValue,
        'has an unknown sort field',
      );
    }
    if (direction == null && value.containsKey('direction')) {
      _add(
        r'$.sort.direction',
        IntentValidationCode.invalidValue,
        'must be ascending or descending',
      );
    }
    if (field == null || direction == null) return null;
    return IntentFieldSort(field: field, direction: direction);
  }

  IntentSortDirection? _parseSortDirection(Object? value) {
    if (value is! String) return null;
    for (final candidate in IntentSortDirection.values) {
      if (candidate.name == value) return candidate;
    }
    return null;
  }

  void _checkFields(
    Map<String, Object?> json,
    Set<String> allowed,
    String path,
  ) {
    for (final field in allowed) {
      if (!json.containsKey(field)) {
        _add('$path.$field', IntentValidationCode.missingField, 'is required');
      }
    }
    for (final field in json.keys) {
      if (!allowed.contains(field)) {
        _add(
          '$path.$field',
          IntentValidationCode.unknownField,
          'is not allowed by IntentCommand v1',
        );
      }
    }
  }

  bool _isJsonScalar(Object? value) =>
      value == null || value is String || value is num || value is bool;

  void _add(String path, IntentValidationCode code, String message) {
    _issues.add(
      IntentValidationIssue(path: path, code: code, message: message),
    );
  }
}
