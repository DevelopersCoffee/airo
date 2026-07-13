import 'package:flutter_chrome_cast/entities.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_player/platform_player.dart';

void main() {
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
}
