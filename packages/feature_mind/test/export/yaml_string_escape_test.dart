import 'package:feature_mind/src/export/domain/yaml_string_escape.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('escapeYamlDoubleQuoted escapes backslashes and double quotes', () {
    expect(escapeYamlDoubleQuoted(r'a\b'), r'a\\b');
    expect(escapeYamlDoubleQuoted('say "hello"'), r'say \"hello\"');
  });
}
