import 'dart:math' as math;

import 'package:feature_iptv/application/multiview_split_ratio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('flex maps 5/50/95 to 50-950, 1-1, 950-50', () {
    expect(MultiviewSplitRatio.five.firstFlex, 50);
    expect(MultiviewSplitRatio.five.secondFlex, 950);
    expect(MultiviewSplitRatio.fifty.firstFlex, 1);
    expect(MultiviewSplitRatio.fifty.secondFlex, 1);
    expect(MultiviewSplitRatio.ninetyFive.firstFlex, 950);
    expect(MultiviewSplitRatio.ninetyFive.secondFlex, 50);
  });

  test('on a 1600px axis five is 5 percent', () {
    expect(effectiveMultiviewSplitMin(1600), closeTo(0.05, 0.0001));
    expect(
      snapMultiviewSplitFraction(0.06, extent: 1600),
      MultiviewSplitRatio.five,
    );
    expect(
      snapMultiviewSplitFraction(0.94, extent: 1600),
      MultiviewSplitRatio.ninetyFive,
    );
  });

  test('on a 360px axis five is the 80dp floor not 5 percent', () {
    expect(effectiveMultiviewSplitMin(360), closeTo(80 / 360, 0.0001));
    expect(
      snapMultiviewSplitFraction(0.05, extent: 360),
      MultiviewSplitRatio.five,
    );
    expect(clampMultiviewSplitFraction(0.05, extent: 360), 80 / 360);
  });

  test('snap prefers fifty on a tie', () {
    expect(
      snapMultiviewSplitFraction(0.50, extent: 1600),
      MultiviewSplitRatio.fifty,
    );
  });

  test('step does not wrap past ninetyFive or five', () {
    expect(
      stepMultiviewSplitRatio(MultiviewSplitRatio.fifty, towardSecond: true),
      MultiviewSplitRatio.ninetyFive,
    );
    expect(
      stepMultiviewSplitRatio(
        MultiviewSplitRatio.ninetyFive,
        towardSecond: true,
      ),
      isNull,
    );
    expect(
      stepMultiviewSplitRatio(MultiviewSplitRatio.five, towardSecond: false),
      isNull,
    );
  });

  test('equal-power gains keep 50/50 near constant power', () {
    final mid = multiviewSplitGains(0.50, extent: 1600, globalVolume: 1);
    expect(mid.first, closeTo(math.sqrt(0.5), 0.01));
    expect(mid.second, closeTo(math.sqrt(0.5), 0.01));
    final quiet = multiviewSplitGains(0.05, extent: 1600, globalVolume: 1);
    expect(quiet.first, closeTo(0, 0.01));
    expect(quiet.second, closeTo(1, 0.01));
    final loud = multiviewSplitGains(0.95, extent: 1600, globalVolume: 0.5);
    expect(loud.first, closeTo(0.5, 0.01));
    expect(loud.second, closeTo(0, 0.01));
  });
}
