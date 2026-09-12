import 'dart:io';

import 'package:core_completion/core_completion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('jsonObjectGbnf has root and required keys', () {
    final grammar = jsonObjectGbnf(requiredKeys: ['id', 'title']);
    expect(grammar, contains('root'));
    expect(grammar, contains('"id"'));
    expect(grammar, contains('"title"'));
  });

  test('jsonObjectGbnf source has no product vocabulary', () {
    final src = File('lib/src/json_object_gbnf.dart').readAsStringSync();
    expect(src.toLowerCase(), isNot(contains('diet')));
    expect(src.toLowerCase(), isNot(contains('meeting')));
    expect(src, isNot(contains('DietProgram')));
  });
}
