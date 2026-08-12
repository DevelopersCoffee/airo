import 'package:equatable/equatable.dart';

import 'eval_metrics.dart';

/// Result of running one COINS-AI eval suite. Every harness under
/// `lib/src/eval/` produces one of these -- this is the shape the
/// milestone-27 gate (#1650's "per-feature scorecards feed milestone gate"
/// acceptance criterion) reads.
class EvalScorecard extends Equatable {
  final String suiteName;
  final int sampleCount;

  /// Accuracy against the baseline being benchmarked (e.g. the regex
  /// categorizer). 1.0 for suites with no meaningful baseline comparison.
  final double accuracy;

  /// True if running the whole suite twice produced identical decisions
  /// for every example -- the "same input, same output, forever" property
  /// every COINS-AI feature is required to hold.
  final bool consistencyInvariantHeld;

  /// Number of examples where the code under test reached a vault
  /// repository or mutated the ledger without an explicit confirm step.
  /// Must be 0 to pass the milestone gate.
  final int vaultBoundaryViolations;

  /// Precision/recall detail for detection-style suites (present/absent
  /// judgments, e.g. "is this a subscription"). Null for categorization
  /// suites, where [accuracy] is the whole story.
  final ClassificationMetrics? detectionMetrics;

  const EvalScorecard({
    required this.suiteName,
    required this.sampleCount,
    required this.accuracy,
    required this.consistencyInvariantHeld,
    required this.vaultBoundaryViolations,
    this.detectionMetrics,
  });

  bool get passes =>
      consistencyInvariantHeld && vaultBoundaryViolations == 0;

  @override
  List<Object?> get props => [
    suiteName,
    sampleCount,
    accuracy,
    consistencyInvariantHeld,
    vaultBoundaryViolations,
    detectionMetrics,
  ];

  @override
  String toString() {
    return 'EvalScorecard($suiteName: n=$sampleCount, '
        'accuracy=${(accuracy * 100).toStringAsFixed(1)}%, '
        'consistency=${consistencyInvariantHeld ? "OK" : "FAILED"}, '
        'vaultViolations=$vaultBoundaryViolations)';
  }
}
