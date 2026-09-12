import 'package:feature_iptv/application/providers/iptv_ad_placements.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const placements = IptvAdPlacements(pauseCard: SizedBox.shrink());

  test('shows a pause card only on a paused fullscreen phone player', () {
    expect(
      iptvPauseAdVisible(
        placements: placements,
        isPlaying: false,
        useTvTransportBar: false,
        isCasting: false,
        isFullscreen: true,
        isPipActive: false,
        blocksPlaybackChrome: false,
      ),
      isTrue,
    );
  });

  test('hides the pause card while playing, casting, or on leanback', () {
    const playing = (
      isPlaying: true,
      useTvTransportBar: false,
      isCasting: false,
      isFullscreen: true,
      isPipActive: false,
      blocksPlaybackChrome: false,
    );
    const leanback = (
      isPlaying: false,
      useTvTransportBar: true,
      isCasting: false,
      isFullscreen: true,
      isPipActive: false,
      blocksPlaybackChrome: false,
    );
    const casting = (
      isPlaying: false,
      useTvTransportBar: false,
      isCasting: true,
      isFullscreen: true,
      isPipActive: false,
      blocksPlaybackChrome: false,
    );
    const preview = (
      isPlaying: false,
      useTvTransportBar: false,
      isCasting: false,
      isFullscreen: false,
      isPipActive: false,
      blocksPlaybackChrome: false,
    );

    for (final case_ in [playing, leanback, casting, preview]) {
      expect(
        iptvPauseAdVisible(
          placements: placements,
          isPlaying: case_.isPlaying,
          useTvTransportBar: case_.useTvTransportBar,
          isCasting: case_.isCasting,
          isFullscreen: case_.isFullscreen,
          isPipActive: case_.isPipActive,
          blocksPlaybackChrome: case_.blocksPlaybackChrome,
        ),
        isFalse,
      );
    }
  });

  test('hides the pause card when the host did not supply one', () {
    expect(
      iptvPauseAdVisible(
        placements: const IptvAdPlacements(),
        isPlaying: false,
        useTvTransportBar: false,
        isCasting: false,
        isFullscreen: true,
        isPipActive: false,
        blocksPlaybackChrome: false,
      ),
      isFalse,
    );
  });
}
