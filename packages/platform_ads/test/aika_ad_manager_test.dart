import 'package:flutter_test/flutter_test.dart';
import 'package:platform_ads/platform_ads.dart';

void main() {
  test('skips Mobile Ads initialization on leanback and desktop', () async {
    var initialized = false;
    final manager = AikaAdManager.test(
      sdk: AikaAdSdk(
        initializeFn: () async {
          initialized = true;
          return true;
        },
      ),
    );

    await manager.initialize(formFactor: AiroDeviceFormFactor.tv);
    expect(initialized, isFalse);
    expect(manager.isSdkReady, isFalse);

    await manager.initialize(formFactor: AiroDeviceFormFactor.desktop);
    expect(initialized, isFalse);
  });

  test('initializes on a phone profile and then applies policy', () async {
    final now = DateTime.utc(2026, 9, 13, 12);
    final policy = AikaAdPolicy(clock: () => now);
    final manager = AikaAdManager.test(
      policy: policy,
      sdk: AikaAdSdk(initializeFn: () async => true),
    );

    await manager.initialize(formFactor: AiroDeviceFormFactor.mobile);
    expect(manager.isSdkReady, isTrue);
    expect(
      manager.shouldShowAd(isLeanback: false, isCasting: false),
      isFalse,
      reason: 'session warmup is still active',
    );
    expect(manager.shouldShowAd(isLeanback: true, isCasting: false), isFalse);
    expect(manager.shouldShowAd(isLeanback: false, isCasting: true), isFalse);
  });
}
