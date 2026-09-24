import 'package:feature_iptv/application/content_source_store.dart';
import 'package:feature_iptv/application/source_stream_headers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_playlist/platform_playlist.dart';

void main() {
  const source = ContentSourceConfig(
    id: 'm3u-1',
    kind: ContentSourceKind.m3u,
    label: 'Portal',
    url: 'https://example.com/list.m3u',
    streamUserAgent: 'Mozilla/5.0',
    streamReferrer: 'https://portal.example/',
  );

  const channel = IPTVChannel(
    id: 'c1',
    name: 'News',
    streamUrl: 'https://cdn.example/stream.m3u8',
    group: 'News',
  );

  test('applies source defaults when channel has no headers', () {
    final updated = applySourceStreamHeaders(channel: channel, source: source);
    expect(updated.headers?.userAgent, 'Mozilla/5.0');
    expect(updated.headers?.referrer, 'https://portal.example/');
  });

  test('does not override channel-specific headers', () {
    final updated = applySourceStreamHeaders(
      channel: channel.copyWith(
        headers: const ChannelHeaders(userAgent: 'Channel UA'),
      ),
      source: source,
    );
    expect(updated.headers?.userAgent, 'Channel UA');
    expect(updated.headers?.referrer, 'https://portal.example/');
  });
}
