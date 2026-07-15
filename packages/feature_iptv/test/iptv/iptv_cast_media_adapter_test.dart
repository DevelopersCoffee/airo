import "package:feature_iptv/feature_iptv.dart";
import 'package:flutter_test/flutter_test.dart';

void main() {
  const adapter = IptvCastMediaAdapter();

  IPTVChannel channel({
    String streamUrl = 'https://example.com/live.m3u8',
    String? logoUrl = 'https://example.com/logo.png',
    ChannelHeaders? headers,
    bool isAudioOnly = false,
    Map<String, String>? qualityUrls,
  }) {
    return IPTVChannel(
      id: 'p4u',
      name: 'P4U Music',
      streamUrl: streamUrl,
      logoUrl: logoUrl,
      group: 'Music',
      category: ChannelCategory.music,
      isAudioOnly: isAudioOnly,
      headers: headers,
      qualityUrls: qualityUrls,
    );
  }

  test('converts HLS channel into live Cast media request', () {
    final result = adapter.toCastRequest(channel());

    expect(result.isCastable, true);
    expect(result.request!.url, Uri.parse('https://example.com/live.m3u8'));
    expect(result.request!.contentType, 'application/vnd.apple.mpegurl');
    expect(result.request!.title, 'P4U Music');
    expect(result.request!.subtitle, 'Music');
    expect(result.request!.imageUrl, Uri.parse('https://example.com/logo.png'));
    expect(result.request!.streamKind, AiroCastMediaStreamKind.live);
  });

  test('converts MP4 channel into buffered Cast media request', () {
    final result = adapter.toCastRequest(
      channel(streamUrl: 'https://example.com/video.mp4?token=abc'),
    );

    expect(result.isCastable, true);
    expect(result.request!.contentType, 'video/mp4');
    expect(result.request!.streamKind, AiroCastMediaStreamKind.buffered);
  });

  test('uses selected quality URL when available', () {
    final result = adapter.toCastRequest(
      channel(
        qualityUrls: const {
          'low': 'https://example.com/low.m3u8',
          'high': 'https://example.com/high.m3u8',
        },
      ),
      selectedQuality: VideoQuality.high,
    );

    expect(result.isCastable, true);
    expect(result.request!.url, Uri.parse('https://example.com/high.m3u8'));
    expect(result.request!.streamKind, AiroCastMediaStreamKind.live);
  });

  test('converts audio-only channel into audio Cast media request', () {
    final result = adapter.toCastRequest(
      channel(streamUrl: 'https://example.com/radio', isAudioOnly: true),
    );

    expect(result.isCastable, true);
    expect(result.request!.contentType, 'audio/mpeg');
    expect(result.request!.streamKind, AiroCastMediaStreamKind.buffered);
  });

  test('rejects channels requiring custom headers in V1', () {
    final result = adapter.toCastRequest(
      channel(headers: const ChannelHeaders(userAgent: 'Airo')),
    );

    expect(result.isCastable, false);
    expect(result.error!.code, AiroCastErrorCode.unsupportedStream);
  });

  test('rejects non-http URLs', () {
    final result = adapter.toCastRequest(
      channel(streamUrl: 'file:///private/video.mp4'),
    );

    expect(result.isCastable, false);
    expect(result.error!.code, AiroCastErrorCode.unsupportedStream);
  });

  test('rejects private network stream URLs', () {
    final result = adapter.toCastRequest(
      channel(streamUrl: 'http://192.168.1.20/live.m3u8'),
    );

    expect(result.isCastable, false);
    expect(result.error!.code, AiroCastErrorCode.unsupportedStream);
  });

  test('drops unsafe artwork URLs from cast metadata', () {
    final result = adapter.toCastRequest(channel(logoUrl: 'javascript:bad()'));

    expect(result.isCastable, true);
    expect(result.request!.imageUrl, isNull);
  });

  test('rejects unknown stream formats', () {
    final result = adapter.toCastRequest(
      channel(streamUrl: 'https://example.com/playlist.ts'),
    );

    expect(result.isCastable, false);
    expect(result.error!.code, AiroCastErrorCode.unsupportedStream);
  });
}
