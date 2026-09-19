import 'package:airo_app/aika_ads/aika_ads.dart';
import 'package:airo_app/aika_ads/aika_ads_runtime.dart';
import 'package:airo_app/aika_ads/aika_browse_native_ad_card.dart';
import 'package:core_app_shell/core_app_shell.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('aikaIptvAdPlacements', () {
    test('keeps the browse grid empty on leanback so no blank fifth tile', () {
      final placements = aikaIptvAdPlacements(
        formFactor: AiroDeviceFormFactor.tv,
      );

      expect(placements.browseCard, isNull);
      expect(placements.pauseCard, isNull);
    });

    test('supplies dismissible native cards on a phone profile', () {
      final placements = aikaIptvAdPlacements(
        formFactor: AiroDeviceFormFactor.mobile,
      );

      expect(placements.browseCard, isA<AikaBrowseNativeAdCard>());
      expect(placements.pauseCard, isA<AikaNativeAdCard>());
      expect(
        (placements.browseCard! as AikaBrowseNativeAdCard).isLeanback,
        isFalse,
      );
      expect((placements.pauseCard! as AikaNativeAdCard).isLeanback, isFalse);
    });
  });

  group('mapDeviceFormFactorToAika', () {
    test('maps phone and TV detections onto the ads SDK enum', () {
      expect(
        mapDeviceFormFactorToAika(DeviceFormFactor.mobile),
        AiroDeviceFormFactor.mobile,
      );
      expect(
        mapDeviceFormFactorToAika(DeviceFormFactor.tv),
        AiroDeviceFormFactor.tv,
      );
      expect(
        mapDeviceFormFactorToAika(DeviceFormFactor.desktop),
        AiroDeviceFormFactor.desktop,
      );
    });
  });

  group('allowImmediateAikaPhoneAds', () {
    test('allows the fifth browse tile as soon as the SDK is ready', () async {
      final now = DateTime.utc(2026, 9, 13, 12);
      final policy = AikaAdPolicy(clock: () => now);
      final manager = AikaAdManager.test(
        policy: policy,
        sdk: AikaAdSdk(initializeFn: () async => true),
      );
      await manager.initialize(formFactor: AiroDeviceFormFactor.mobile);

      expect(
        manager.shouldShowAd(isLeanback: false, isCasting: false),
        isFalse,
        reason: 'hosted policy still starts in warmup',
      );

      allowImmediateAikaPhoneAds(manager, now: () => now);

      expect(delayUntilAikaAdsAllowed(manager, now: () => now), Duration.zero);
      expect(manager.shouldShowAd(isLeanback: false, isCasting: false), isTrue);
    });

    test('does not arm ads when the SDK stayed skipped on TV', () async {
      final manager = AikaAdManager.test(
        sdk: AikaAdSdk(initializeFn: () async => true),
      );
      await manager.initialize(formFactor: AiroDeviceFormFactor.tv);

      expect(shouldArmAikaPhoneAds(AiroDeviceFormFactor.tv, manager), isFalse);
      expect(
        shouldArmAikaPhoneAds(AiroDeviceFormFactor.mobile, manager),
        isFalse,
      );
    });
  });
}
