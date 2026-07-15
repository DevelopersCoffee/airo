import 'package:core_data/core_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('KeyValueStore.assertValueSize', () {
    test('allows values within the 64KB limit', () {
      // Should not throw for a value under the limit.
      expect(
        () => KeyValueStore.assertValueSize('short value', 'test_key'),
        returnsNormally,
      );
    });

    test('allows values at exactly the limit', () {
      final value = 'x' * KeyValueStore.maxValueChars;
      expect(
        () => KeyValueStore.assertValueSize(value, 'test_key'),
        returnsNormally,
      );
    });

    test('rejects values exceeding the 64KB limit in debug mode', () {
      final oversized = 'x' * (KeyValueStore.maxValueChars + 1);
      expect(
        () => KeyValueStore.assertValueSize(oversized, 'big_key'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Value too large for prefs tier'),
          ),
        ),
      );
    });

    test('error message includes key name and actual size', () {
      final oversized = 'x' * (KeyValueStore.maxValueChars + 100);
      expect(
        () => KeyValueStore.assertValueSize(oversized, 'my_key'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('my_key'),
              contains('${oversized.length}'),
            ),
          ),
        ),
      );
    });

    test('maxValueChars is 65536', () {
      expect(KeyValueStore.maxValueChars, 65536);
    });
  });
}
