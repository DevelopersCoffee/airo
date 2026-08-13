import '../entities/transaction.dart';
import '../services/recurrence_anomaly_detector.dart';
import 'eval_metrics.dart';
import 'eval_scorecard.dart';

/// One single-merchant scenario judged for whether it should be flagged
/// as a subscription.
class RecurrenceEvalCase {
  final String name;
  final List<Transaction> transactions;
  final bool expectSubscription;

  const RecurrenceEvalCase({
    required this.name,
    required this.transactions,
    required this.expectSubscription,
  });
}

/// Runs COINS-AI-6's [RecurrenceAnomalyDetector] against a golden set of
/// single-merchant ledgers, scoring subscription-detection precision and
/// recall. Pure computation over caller-supplied transactions -- no vault
/// repository access, so [EvalScorecard.vaultBoundaryViolations] is always
/// 0 by construction here, same as [MerchantCategorizationEvalHarness].
class RecurrenceDetectorEvalHarness {
  const RecurrenceDetectorEvalHarness();

  EvalScorecard run(
    List<RecurrenceEvalCase> cases,
    RecurrenceAnomalyDetector detector,
  ) {
    final firstPass = [
      for (final c in cases) detector.detectSubscriptions(c.transactions).isNotEmpty,
    ];
    final secondPass = [
      for (final c in cases) detector.detectSubscriptions(c.transactions).isNotEmpty,
    ];
    final consistencyHeld = _listsEqual(firstPass, secondPass);

    var tp = 0;
    var fp = 0;
    var fn = 0;
    var tn = 0;
    for (var i = 0; i < cases.length; i++) {
      final predicted = firstPass[i];
      final expected = cases[i].expectSubscription;
      if (predicted && expected) {
        tp++;
      } else if (predicted && !expected) {
        fp++;
      } else if (!predicted && expected) {
        fn++;
      } else {
        tn++;
      }
    }
    final metrics = ClassificationMetrics(
      truePositives: tp,
      falsePositives: fp,
      falseNegatives: fn,
    );

    return EvalScorecard(
      suiteName: 'coins-ai-6-recurrence-detection',
      sampleCount: cases.length,
      accuracy: (tp + tn) / cases.length,
      consistencyInvariantHeld: consistencyHeld,
      vaultBoundaryViolations: 0,
      detectionMetrics: metrics,
    );
  }

  bool _listsEqual(List<bool> a, List<bool> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
