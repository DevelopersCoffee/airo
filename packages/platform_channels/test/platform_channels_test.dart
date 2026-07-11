import 'package:flutter_test/flutter_test.dart';
import 'package:platform_channels/platform_channels.dart';

void main() {
  test('IPTVChannel round-trips channel metadata', () {
    const channel = IPTVChannel(
      id: 'news-1',
      name: 'News One',
      streamUrl: 'https://example.com/news.m3u8',
      category: ChannelCategory.news,
      flavor: ChannelFlavor.englishNews,
      headers: ChannelHeaders(userAgent: 'Airo'),
    );

    final restored = IPTVChannel.fromJson(channel.toJson());

    expect(restored.id, channel.id);
    expect(restored.category, ChannelCategory.news);
    expect(restored.flavor, ChannelFlavor.englishNews);
    expect(restored.headers?.userAgent, 'Airo');
  });
}
