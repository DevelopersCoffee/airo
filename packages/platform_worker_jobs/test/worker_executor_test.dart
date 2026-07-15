import 'package:flutter_test/flutter_test.dart';
import 'package:platform_worker_jobs/platform_worker_jobs.dart';

int _sumValues(List<int> values) {
  return values.fold<int>(0, (total, value) => total + value);
}

Never _throwWorkerError() {
  throw StateError('worker failed');
}

void main() {
  group('AiroWorkerExecutor', () {
    test('runs a sendable computation off the caller path', () async {
      final result = await const AiroWorkerExecutor().run<int>(
        debugName: 'sum-values',
        kind: AiroWorkerJobKind.playlistImport,
        computation: () => _sumValues(const [1, 2, 3, 4]),
      );

      expect(result, 10);
    });

    test('propagates computation failures to the caller', () async {
      await expectLater(
        const AiroWorkerExecutor().run<Never>(
          debugName: 'throw-worker-error',
          kind: AiroWorkerJobKind.playlistImport,
          computation: _throwWorkerError,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('supports deterministic inline execution', () async {
      var calls = 0;

      final result = await const AiroWorkerExecutor(forceInline: true).run<int>(
        debugName: 'inline-worker',
        kind: AiroWorkerJobKind.searchIndexing,
        computation: () {
          calls++;
          return 42;
        },
      );

      expect(result, 42);
      expect(calls, 1);
    });
  });
}
