import 'dart:math' as math;

enum MultiviewSplitRatio {
  five,
  fifty,
  ninetyFive;

  int get firstFlex => switch (this) {
    five => 50,
    fifty => 1,
    ninetyFive => 950,
  };

  int get secondFlex => switch (this) {
    five => 950,
    fifty => 1,
    ninetyFive => 50,
  };

  double get firstFraction => switch (this) {
    five => 0.05,
    fifty => 0.50,
    ninetyFive => 0.95,
  };
}

const double kMultiviewSplitMinFraction = 0.05;
const double kMultiviewSplitMaxFraction = 0.95;
const double kMultiviewMinPaneDp = 80;

double effectiveMultiviewSplitMin(double extent) {
  if (extent <= 0) return kMultiviewSplitMinFraction;
  final floor = kMultiviewMinPaneDp / extent;
  return math.max(kMultiviewSplitMinFraction, floor);
}

double clampMultiviewSplitFraction(double fraction, {required double extent}) {
  final min = effectiveMultiviewSplitMin(extent);
  final max = 1 - min;
  if (fraction < min) return min;
  if (fraction > max) return max;
  return fraction;
}

MultiviewSplitRatio snapMultiviewSplitFraction(
  double fraction, {
  required double extent,
}) {
  final min = effectiveMultiviewSplitMin(extent);
  final max = 1 - min;
  final clamped = clampMultiviewSplitFraction(fraction, extent: extent);
  final dFive = (clamped - min).abs();
  final dFifty = (clamped - 0.50).abs();
  final dNinetyFive = (clamped - max).abs();
  if (dFifty <= dFive && dFifty <= dNinetyFive) {
    return MultiviewSplitRatio.fifty;
  }
  if (dFive < dNinetyFive) return MultiviewSplitRatio.five;
  return MultiviewSplitRatio.ninetyFive;
}

MultiviewSplitRatio? stepMultiviewSplitRatio(
  MultiviewSplitRatio current, {
  required bool towardSecond,
}) {
  if (towardSecond) {
    return switch (current) {
      MultiviewSplitRatio.five => MultiviewSplitRatio.fifty,
      MultiviewSplitRatio.fifty => MultiviewSplitRatio.ninetyFive,
      MultiviewSplitRatio.ninetyFive => null,
    };
  }
  return switch (current) {
    MultiviewSplitRatio.ninetyFive => MultiviewSplitRatio.fifty,
    MultiviewSplitRatio.fifty => MultiviewSplitRatio.five,
    MultiviewSplitRatio.five => null,
  };
}

class MultiviewSplitGains {
  const MultiviewSplitGains({required this.first, required this.second});
  final double first;
  final double second;
}

MultiviewSplitGains multiviewSplitGains(
  double firstFraction, {
  required double extent,
  required double globalVolume,
}) {
  final min = effectiveMultiviewSplitMin(extent);
  final max = 1 - min;
  final f = clampMultiviewSplitFraction(firstFraction, extent: extent);
  final span = max - min;
  final t = span <= 0 ? 0.5 : ((f - min) / span).clamp(0.0, 1.0);
  final g = globalVolume.clamp(0.0, 1.0);
  return MultiviewSplitGains(
    first: math.sqrt(t) * g,
    second: math.sqrt(1 - t) * g,
  );
}
