import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// In-app ad slots for Aika Stream. The TV app overrides this with AdMob
/// Native cards. `feature_iptv` never imports `google_mobile_ads`.
class IptvAdPlacements {
  const IptvAdPlacements({this.browseCard, this.pauseCard});

  final Widget? browseCard;
  final Widget? pauseCard;
}

final iptvAdPlacementsProvider = Provider<IptvAdPlacements>(
  (ref) => const IptvAdPlacements(),
);

/// Pause-card visibility for the fullscreen player. Browse preview, Cast,
/// leanback, PiP, and error/loading chrome never show an ad.
bool iptvPauseAdVisible({
  required IptvAdPlacements placements,
  required bool isPlaying,
  required bool useTvTransportBar,
  required bool isCasting,
  required bool isFullscreen,
  required bool isPipActive,
  required bool blocksPlaybackChrome,
}) {
  return placements.pauseCard != null &&
      !isPlaying &&
      !useTvTransportBar &&
      !isCasting &&
      isFullscreen &&
      !isPipActive &&
      !blocksPlaybackChrome;
}
