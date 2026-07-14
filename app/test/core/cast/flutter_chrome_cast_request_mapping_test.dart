import 'package:airo_app/core/cast/cast.dart';
import 'package:airo_app/core/cast/flutter_chrome_cast_controller.dart';
import 'package:flutter_chrome_cast/entities.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('disables Cast analytics logging during initialization', () {
    final options = FlutterChromeCastController.buildCastOptions();

    expect(options.toMap()['disableAnalyticsLogging'], isTrue);
    expect(options.toMap()['disableDiscoveryAutostart'], isTrue);
  });

  test('maps Airo live HLS request to GoogleCastMediaInformation', () {
    final request = AiroCastMediaRequest(
      url: Uri.parse('https://example.com/channel.m3u8'),
      contentType: 'application/x-mpegURL',
      title: 'P4U Music',
      subtitle: 'Music',
      imageUrl: Uri.parse('https://example.com/logo.png'),
      streamKind: AiroCastMediaStreamKind.live,
    );

    final mediaInfo = FlutterChromeCastController.toGoogleMediaInfo(request);

    expect(mediaInfo, isA<GoogleCastMediaInformation>());
    expect(mediaInfo.contentId, 'https://example.com/channel.m3u8');
    expect(mediaInfo.contentUrl, Uri.parse('https://example.com/channel.m3u8'));
    expect(mediaInfo.contentType, 'application/x-mpegURL');
    expect(mediaInfo.streamType, CastMediaStreamType.live);
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
