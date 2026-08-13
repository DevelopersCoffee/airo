/// Precision/recall/F1 over a boolean prediction set. Shared by every
/// COINS-AI eval harness (COINS-AI-7) -- one metrics implementation, not a
/// reimplementation per feature.
class ClassificationMetrics {
  final int truePositives;
  final int falsePositives;
  final int falseNegatives;

  const ClassificationMetrics({
    required this.truePositives,
    required this.falsePositives,
    required this.falseNegatives,
  });

  double get precision {
    final denom = truePositives + falsePositives;
    return denom == 0 ? 1.0 : truePositives / denom;
  }

  double get recall {
    final denom = truePositives + falseNegatives;
    return denom == 0 ? 1.0 : truePositives / denom;
  }

  double get f1 {
    final p = precision;
    final r = recall;
    if (p + r == 0) return 0.0;
    return 2 * p * r / (p + r);
  }
}

/// Exact-match accuracy over labeled examples where `actual(example) ==
/// expected(example)`. Used for categorization-style eval (one predicted
/// label per example), as opposed to [ClassificationMetrics] (used for
/// detection-style eval, where a feature can be present or absent).
double exactMatchAccuracy<T, E>(
  List<T> examples,
  E Function(T) expected,
  E Function(T) actual,
) {
  if (examples.isEmpty) return 1.0;
  final correct = examples.where((e) => actual(e) == expected(e)).length;
  return correct / examples.length;
}
