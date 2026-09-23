import 'package:feature_iptv/application/multiview_split_ratio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('flex maps 30/50/70 to 3-7, 1-1, 7-3', () {
    expect(MultiviewSplitRatio.thirty.firstFlex, 3);
    expect(MultiviewSplitRatio.thirty.secondFlex, 7);
    expect(MultiviewSplitRatio.fifty.firstFlex, 1);
    expect(MultiviewSplitRatio.fifty.secondFlex, 1);
    expect(MultiviewSplitRatio.seventy.firstFlex, 7);
    expect(MultiviewSplitRatio.seventy.secondFlex, 3);
  });

  test('snap prefers fifty on a tie between two stops', () {
    expect(snapMultiviewSplitFraction(0.40), MultiviewSplitRatio.fifty);
    expect(snapMultiviewSplitFraction(0.60), MultiviewSplitRatio.fifty);
    expect(snapMultiviewSplitFraction(0.50), MultiviewSplitRatio.fifty);
  });

  test('snap picks the nearest stop and clamps outside 30-70', () {
    expect(snapMultiviewSplitFraction(0.30), MultiviewSplitRatio.thirty);
    expect(snapMultiviewSplitFraction(0.31), MultiviewSplitRatio.thirty);
    expect(snapMultiviewSplitFraction(0.69), MultiviewSplitRatio.seventy);
    expect(snapMultiviewSplitFraction(0.70), MultiviewSplitRatio.seventy);
    expect(snapMultiviewSplitFraction(0.0), MultiviewSplitRatio.thirty);
    expect(snapMultiviewSplitFraction(1.0), MultiviewSplitRatio.seventy);
  });

  test('step toward second does not wrap past seventy', () {
    expect(
      stepMultiviewSplitRatio(MultiviewSplitRatio.fifty, towardSecond: true),
      MultiviewSplitRatio.seventy,
    );
    expect(
      stepMultiviewSplitRatio(MultiviewSplitRatio.seventy, towardSecond: true),
      isNull,
    );
  });

  test('step toward first does not wrap past thirty', () {
    expect(
      stepMultiviewSplitRatio(MultiviewSplitRatio.fifty, towardSecond: false),
      MultiviewSplitRatio.thirty,
    );
    expect(
      stepMultiviewSplitRatio(MultiviewSplitRatio.thirty, towardSecond: false),
      isNull,
    );
  });

  test('clamp keeps a live drag inside 30-70', () {
    expect(clampMultiviewSplitFraction(0.10), 0.30);
    expect(clampMultiviewSplitFraction(0.55), 0.55);
    expect(clampMultiviewSplitFraction(0.90), 0.70);
  });
}
