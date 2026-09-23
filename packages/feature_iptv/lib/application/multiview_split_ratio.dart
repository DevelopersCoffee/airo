enum MultiviewSplitRatio {
  thirty,
  fifty,
  seventy;

  int get firstFlex => switch (this) {
    thirty => 3,
    fifty => 1,
    seventy => 7,
  };

  int get secondFlex => switch (this) {
    thirty => 7,
    fifty => 1,
    seventy => 3,
  };

  double get firstFraction => switch (this) {
    thirty => 0.30,
    fifty => 0.50,
    seventy => 0.70,
  };
}

const double kMultiviewSplitMinFraction = 0.30;
const double kMultiviewSplitMaxFraction = 0.70;

double clampMultiviewSplitFraction(double fraction) {
  if (fraction < kMultiviewSplitMinFraction) {
    return kMultiviewSplitMinFraction;
  }
  if (fraction > kMultiviewSplitMaxFraction) {
    return kMultiviewSplitMaxFraction;
  }
  return fraction;
}

MultiviewSplitRatio snapMultiviewSplitFraction(double fraction) {
  final clamped = clampMultiviewSplitFraction(fraction);
  final d30 = (clamped - 0.30).abs();
  final d50 = (clamped - 0.50).abs();
  final d70 = (clamped - 0.70).abs();
  if (d50 <= d30 && d50 <= d70) return MultiviewSplitRatio.fifty;
  if (d30 < d70) return MultiviewSplitRatio.thirty;
  return MultiviewSplitRatio.seventy;
}

/// Next stop along the split axis. Null means "do not wrap; let focus leave
/// the handle toward the already-small pane."
MultiviewSplitRatio? stepMultiviewSplitRatio(
  MultiviewSplitRatio current, {
  required bool towardSecond,
}) {
  if (towardSecond) {
    return switch (current) {
      MultiviewSplitRatio.thirty => MultiviewSplitRatio.fifty,
      MultiviewSplitRatio.fifty => MultiviewSplitRatio.seventy,
      MultiviewSplitRatio.seventy => null,
    };
  }
  return switch (current) {
    MultiviewSplitRatio.seventy => MultiviewSplitRatio.fifty,
    MultiviewSplitRatio.fifty => MultiviewSplitRatio.thirty,
    MultiviewSplitRatio.thirty => null,
  };
}
