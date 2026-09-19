import 'package:core_app_shell/core_app_shell.dart';
import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'aika_ads.dart';
import 'aika_browse_native_ad_card.dart';

/// Starts empty so leanback never reserves a fifth tile. Phone browse ads
/// are armed as soon as the SDK is ready.
final aikaIptvAdPlacementsStateProvider = StateProvider<IptvAdPlacements>(
  (ref) => const IptvAdPlacements(),
);

AiroDeviceFormFactor mapDeviceFormFactorToAika(DeviceFormFactor formFactor) {
  return switch (formFactor) {
    DeviceFormFactor.mobile => AiroDeviceFormFactor.mobile,
    DeviceFormFactor.tablet => AiroDeviceFormFactor.tablet,
    DeviceFormFactor.tv => AiroDeviceFormFactor.tv,
    DeviceFormFactor.desktop => AiroDeviceFormFactor.desktop,
  };
}

Future<AiroDeviceFormFactor> detectAikaAdFormFactor() async {
  return mapDeviceFormFactorToAika(await DeviceFormFactorDetector.detect(null));
}

IptvAdPlacements aikaIptvAdPlacements({
  required AiroDeviceFormFactor formFactor,
}) {
  switch (formFactor) {
    case AiroDeviceFormFactor.mobile:
    case AiroDeviceFormFactor.tablet:
      return const IptvAdPlacements(
        browseCard: AikaBrowseNativeAdCard(),
        pauseCard: AikaNativeAdCard(placement: AikaAdPlacement.pause),
      );
    case AiroDeviceFormFactor.tv:
    case AiroDeviceFormFactor.desktop:
    case AiroDeviceFormFactor.unknown:
      return const IptvAdPlacements();
  }
}

bool shouldArmAikaPhoneAds(
  AiroDeviceFormFactor formFactor,
  AikaAdManager manager,
) {
  if (formFactor == AiroDeviceFormFactor.tv ||
      formFactor == AiroDeviceFormFactor.desktop ||
      formFactor == AiroDeviceFormFactor.unknown) {
    return false;
  }
  return manager.isSdkReady;
}

/// The hosted [AikaAdPolicy] still starts with a 5-minute warmup, which
/// would leave the fifth library tile empty. Backdate the session so the
/// browse Native card can load immediately after SDK init.
void allowImmediateAikaPhoneAds(
  AikaAdManager manager, {
  DateTime Function()? now,
}) {
  if (!manager.isSdkReady) return;
  final clock = now ?? DateTime.now;
  manager.policy.startSession(clock().subtract(manager.policy.sessionWarmup));
}

Duration delayUntilAikaAdsAllowed(
  AikaAdManager manager, {
  DateTime Function()? now,
}) {
  if (!manager.isSdkReady) {
    return AikaAdPolicy.defaultSessionWarmup;
  }
  if (manager.shouldShowAd(isLeanback: false, isCasting: false)) {
    return Duration.zero;
  }
  final started = manager.policy.sessionStartedAt;
  final clock = now ?? DateTime.now;
  if (started == null) return manager.policy.sessionWarmup;
  final remaining = manager.policy.sessionWarmup - clock().difference(started);
  if (remaining.isNegative) return Duration.zero;
  return remaining;
}
