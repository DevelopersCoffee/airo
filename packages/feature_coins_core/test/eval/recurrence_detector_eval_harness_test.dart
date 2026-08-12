import 'package:feature_coins_core/src/eval/recurrence_detector_eval_harness.dart';
import 'package:feature_coins_core/src/services/recurrence_anomaly_detector.dart';
import 'package:test/test.dart';

import 'golden/synthetic_ledgers_v1.dart';

void main() {
  group('RecurrenceDetectorEvalHarness against syntheticLedgersV1', () {
    const harness = RecurrenceDetectorEvalHarness();
    final cases = [
      for (final g in syntheticLedgersV1)
        RecurrenceEvalCase(
          name: g.name,
          transactions: g.transactions,
          expectSubscription: g.expectSubscription,
        ),
    ];

    test('scorecard passes with perfect precision and recall', () {
      const detector = RecurrenceAnomalyDetector();

      final scorecard = harness.run(cases, detector);

      expect(scorecard.sampleCount, syntheticLedgersV1.length);
      expect(scorecard.passes, isTrue);
      expect(scorecard.detectionMetrics, isNotNull);
      expect(scorecard.detectionMetrics!.precision, 1.0);
      expect(scorecard.detectionMetrics!.recall, 1.0);
    });
  });
}
