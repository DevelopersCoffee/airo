import 'package:core_app_shell/core_app_shell.dart';
import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'aika_ads.dart';

/// Starts empty so the browse grid has no blank fifth tile while ads warm up
/// or while the host is leanback.
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
        browseCard: AikaNativeAdCard(placement: AikaAdPlacement.browse),
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
