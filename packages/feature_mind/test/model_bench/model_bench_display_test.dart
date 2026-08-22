import 'package:feature_mind/src/model_bench/model_bench_display.dart';
import 'package:feature_mind/src/runtime/models/model_models.dart';
import 'package:flutter_test/flutter_test.dart';

ModelBench _bench({ThermalState under = ThermalState.nominal}) => ModelBench(
  tokensPerSecond: 24.5,
  firstTokenMs: 420,
  residentBytes: 2600000000,
  batteryPercentPerHour: 9,
  measuredUnder: under,
  measuredAtMs: 1785827524000,
);

void main() {
  group('ModelBenchDisplay non-happy states', () {
    test('not-run carries no bench and no progress', () {
      const display = ModelBenchDisplay.notRun;

      expect(display.status, ModelBenchStatus.notRun);
      expect(display.bench, isNull);
      expect(display.progress, isNull);
      expect(display.staleReason, isNull);
    });

    test('in-progress carries a progress number, not a bench', () {
      const display = ModelBenchDisplay(
        status: ModelBenchStatus.inProgress,
        progress: 0.4,
      );

      expect(display.progress, 0.4);
      expect(display.bench, isNull);
    });

    test('stale names why the reading no longer applies', () {
      final display = ModelBenchDisplay(
        status: ModelBenchStatus.stale,
        bench: _bench(),
        staleReason: ModelBenchStaleReason.thermalChanged,
      );

      expect(display.staleReason, ModelBenchStaleReason.thermalChanged);
      // The old reading is still attached -- stale is not the same as
      // notRun, a surface can still show "last measured under nominal".
      expect(display.bench, isNotNull);
    });

    test('measured without a bench reading is a programmer error', () {
      // Non-const: an assert violated in a const context is a compile-time
      // error, not the runtime AssertionError this test asserts on.
      expect(
        () => ModelBenchDisplay(status: ModelBenchStatus.measured),
        throwsA(isA<AssertionError>()),
      );
    });

    test('stale without a reason is a programmer error', () {
      expect(
        () =>
            ModelBenchDisplay(status: ModelBenchStatus.stale, bench: _bench()),
        throwsA(isA<AssertionError>()),
      );
    });

    test('progress on a non-in-progress status is a programmer error', () {
      expect(
        () => ModelBenchDisplay(status: ModelBenchStatus.notRun, progress: 0.5),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('value semantics', () {
    test('two measured displays with the same bench are equal', () {
      final a = ModelBenchDisplay(
        status: ModelBenchStatus.measured,
        bench: _bench(),
      );
      final b = ModelBenchDisplay(
        status: ModelBenchStatus.measured,
        bench: _bench(),
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  group('copyWith', () {
    test('clearing progress drops it even when a new value is not given', () {
      const display = ModelBenchDisplay(
        status: ModelBenchStatus.inProgress,
        progress: 0.6,
      );

      final cleared = display.copyWith(
        status: ModelBenchStatus.notRun,
        clearProgress: true,
      );

      expect(cleared.progress, isNull);
    });
  });
}
