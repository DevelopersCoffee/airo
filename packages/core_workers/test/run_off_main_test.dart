import 'package:core_workers/core_workers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('runOffMain', () {
    test('returns computation result', () async {
      final result = await runOffMain(() => 1 + 1);
      expect(result, 2);
    });

    test('returns string computation', () async {
      final result = await runOffMain(() => 'hello'.toUpperCase());
      expect(result, 'HELLO');
    });

    test('propagates exceptions', () async {
      expect(
        () => runOffMain<int>(() => throw StateError('boom')),
        throwsStateError,
      );
    });
  });
}
