import 'package:core_ai/core_ai.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const validator = AddonManifestValidator();

  test('rejects unknown schema version', () {
    final result = validator.validate({
      'schema_version': '9.9',
      'id': 'sample-addon',
      'version': '1.0.0',
      'behaviors': ['generative'],
      'capabilities': ['conversation.current_turn'],
      'tools': [],
    });
    expect(result.isValid, isFalse);
    expect(result.errors, contains(startsWith('unsupported schema_version')));
  });

  test('rejects undeclared tool', () {
    final result = validator.validate({
      'schema_version': '1.0',
      'id': 'sample-addon',
      'version': '1.0.0',
      'behaviors': ['generative'],
      'capabilities': ['conversation.current_turn'],
      'tools': ['unknown_tool'],
    });
    expect(result.isValid, isFalse);
    expect(result.errors, contains('undeclared tool: unknown_tool'));
  });

  test('rejects memory.write capability', () {
    final result = validator.validate({
      'schema_version': '1.0',
      'id': 'sample-addon',
      'version': '1.0.0',
      'behaviors': ['generative'],
      'capabilities': ['memory.write'],
      'tools': [],
    });
    expect(result.isValid, isFalse);
    expect(result.errors, contains('memory.write is unsupported in this migration'));
  });
}
