import 'package:flutter_chrome_cast/entities.dart';
import 'package:flutter_chrome_cast/enums.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_player/platform_player.dart';

void main() {
  group('Cast options', () {
    test('disable analytics logging for Android Cast initialization', () {
      final options = FlutterChromeCastController.buildCastOptions(
        isAndroid: true,
        isIOS: false,
      );

      expect(options.toMap()['disableAnalyticsLogging'], isTrue);
      expect(options.toMap()['disableDiscoveryAutostart'], isTrue);
    });

    test('disable analytics logging for iOS Cast initialization', () {
      final options = FlutterChromeCastController.buildCastOptions(
        isAndroid: false,
        isIOS: true,
      );

      expect(options.toMap()['disableAnalyticsLogging'], isTrue);
      expect(options.toMap()['disableDiscoveryAutostart'], isTrue);
    });
  });

  test('maps live HLS request to Google Cast media information', () {
    final request = AiroCastMediaRequest(
      url: Uri.parse('https://example.com/channel.m3u8'),
      contentType: 'application/vnd.apple.mpegurl',
      title: 'P4U Music',
      subtitle: 'Music',
      imageUrl: Uri.parse('https://example.com/logo.png'),
      streamKind: AiroCastMediaStreamKind.live,
    );

    final mediaInfo = FlutterChromeCastController.toGoogleMediaInfo(
      request,
      hlsVideoSegmentFormat: HlsVideoSegmentFormat.fmp4,
    );

    expect(mediaInfo, isA<GoogleCastMediaInformation>());
    expect(mediaInfo.contentId, 'https://example.com/channel.m3u8');
    expect(mediaInfo.contentUrl, Uri.parse('https://example.com/channel.m3u8'));
    expect(mediaInfo.contentType, 'application/vnd.apple.mpegurl');
    expect(mediaInfo.streamType, CastMediaStreamType.live);
    expect(mediaInfo.hlsVideoSegmentFormat, HlsVideoSegmentFormat.fmp4);
  });

  test('maps buffered MP4 request to buffered stream type', () {
    final request = AiroCastMediaRequest(
      url: Uri.parse('https://example.com/video.mp4'),
      contentType: 'video/mp4',
      title: 'Sample',
      streamKind: AiroCastMediaStreamKind.buffered,
    );

    final mediaInfo = FlutterChromeCastController.toGoogleMediaInfo(request);

    expect(mediaInfo.streamType, CastMediaStreamType.buffered);
  });

  test('ignores stale receiver status for previous media content id', () {
    const tv = AiroCastDevice(id: 'tv-1', name: 'Sony Bravia');
    final current = AiroCastMediaRequest(
      url: Uri.parse('https://example.com/current.m3u8'),
      contentType: 'application/vnd.apple.mpegurl',
      title: 'Current',
      streamKind: AiroCastMediaStreamKind.live,
    );
    final controller = FlutterChromeCastController();

    controller.debugSetConnectedSession(
      device: tv,
      media: current,
      playbackUrl: Uri.parse('http://192.168.1.20:43123/proxy?url=current'),
      phase: AiroCastSessionPhase.loadingMedia,
    );

    controller.debugApplyMediaStatus(
      _status(
        CastMediaPlayerState.idle,
        contentId: 'http://192.168.1.20:43123/proxy?url=previous',
        idleReason: GoogleCastMediaIdleReason.error,
      ),
    );

    expect(
      controller.currentSessionState.phase,
      AiroCastSessionPhase.loadingMedia,
    );
    expect(controller.currentSessionState.media, current);

    controller.debugApplyMediaStatus(
      _status(
        CastMediaPlayerState.playing,
        contentId: 'http://192.168.1.20:43123/proxy?url=current',
        volume: 0.7,
      ),
    );

    expect(controller.currentSessionState.phase, AiroCastSessionPhase.playing);
    expect(controller.currentSessionState.media, current);
    expect(controller.currentSessionState.volume, 0.7);
  });

  test('surfaces receiver idle error while a new media load is active', () {
    const tv = AiroCastDevice(id: 'tv-1', name: 'Sony Bravia');
    final current = AiroCastMediaRequest(
      url: Uri.parse('https://example.com/current.m3u8'),
      contentType: 'application/vnd.apple.mpegurl',
      title: 'Current',
      streamKind: AiroCastMediaStreamKind.live,
    );
    final controller = FlutterChromeCastController();

    controller.debugSetConnectedSession(
      device: tv,
      media: current,
      phase: AiroCastSessionPhase.loadingMedia,
    );

    controller.debugApplyMediaStatus(
      _status(
        CastMediaPlayerState.idle,
        idleReason: GoogleCastMediaIdleReason.error,
      ),
    );

    expect(controller.currentSessionState.phase, AiroCastSessionPhase.failed);
    expect(controller.currentSessionState.media, current);
    expect(
      controller.currentSessionState.error?.code,
      AiroCastErrorCode.mediaLoadFailed,
    );
  });
}

GoggleCastMediaStatus _status(
  CastMediaPlayerState playerState, {
  String? contentId,
  GoogleCastMediaIdleReason? idleReason,
  double volume = 1,
}) {
  return GoggleCastMediaStatus(
    mediaSessionID: 1,
    playerState: playerState,
    idleReason: idleReason,
    playbackRate: 1,
    mediaInformation: contentId == null
        ? null
        : GoogleCastMediaInformation(
            contentId: contentId,
            streamType: CastMediaStreamType.live,
            contentType: 'application/vnd.apple.mpegurl',
          ),
    volume: volume,
    isMuted: false,
    repeatMode: GoogleCastMediaRepeatMode.off,
  );
}
