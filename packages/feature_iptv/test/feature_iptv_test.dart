import 'package:flutter_test/flutter_test.dart';

import 'package:feature_iptv/feature_iptv.dart';

void main() {
  test('exports IPTV platform channel model', () {
    const channel = IPTVChannel(
      id: 'news',
      name: 'News',
      streamUrl: 'https://example.com/news.m3u8',
    );

    expect(channel.getStreamUrl(), 'https://example.com/news.m3u8');
  });
}
