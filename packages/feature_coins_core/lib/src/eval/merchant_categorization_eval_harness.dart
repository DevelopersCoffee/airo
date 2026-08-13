import '../models/merchant_category.dart';
import '../services/merchant_categorizer.dart';
import '../services/regex_merchant_categorizer.dart';
import 'eval_metrics.dart';
import 'eval_scorecard.dart';

/// One golden example, decoupled from any particular fixture format so
/// this harness doesn't import test-only code from `lib/`.
class MerchantEvalExample {
  final String text;
  final MerchantCategory expected;

  const MerchantEvalExample(this.text, this.expected);
}

/// Runs COINS-AI-5's [MerchantCategorizer] against a golden set, scored
/// against the [RegexMerchantCategorizer] baseline it's required to beat.
///
/// This harness never touches a vault repository or the ledger -- it only
/// calls pure classification functions on caller-supplied strings, so its
/// vault-boundary violation count is always 0 by construction. A future
/// harness over a real extraction pipeline (once COINS-AI-1 lands) is
/// where that count becomes a meaningful measurement instead of a
/// structural guarantee.
class MerchantCategorizationEvalHarness {
  const MerchantCategorizationEvalHarness();

  EvalScorecard run(
    List<MerchantEvalExample> examples,
    MerchantCategorizer categorizer,
  ) {
    final firstPass = [
      for (final e in examples) categorizer.categorize(e.text),
    ];
    final secondPass = [
      for (final e in examples) categorizer.categorize(e.text),
    ];
    final consistencyHeld = _listsEqual(firstPass, secondPass);

    final accuracy = exactMatchAccuracy<MerchantEvalExample, MerchantCategory>(
      examples,
      (e) => e.expected,
      (e) => categorizer.categorize(e.text),
    );

    return EvalScorecard(
      suiteName: 'coins-ai-5-merchant-categorization',
      sampleCount: examples.length,
      accuracy: accuracy,
      consistencyInvariantHeld: consistencyHeld,
      vaultBoundaryViolations: 0,
    );
  }

  /// Same golden set, scored against the regex baseline alone -- what
  /// [run]'s accuracy is required to be at least as good as.
  double baselineAccuracy(
    List<MerchantEvalExample> examples,
    RegexMerchantCategorizer baseline,
  ) {
    return exactMatchAccuracy<MerchantEvalExample, MerchantCategory>(
      examples,
      (e) => e.expected,
      (e) => baseline.categorize(e.text),
    );
  }

  bool _listsEqual(List<MerchantCategory> a, List<MerchantCategory> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
