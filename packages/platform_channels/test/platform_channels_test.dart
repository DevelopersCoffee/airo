import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  group('ChannelDataService', () {
    test('returns no first-party channels for Play Store V2', () async {
      SharedPreferences.setMockInitialValues({
        'iptv_channels_cache':
            '{"channels":[{"id":"1","name":"Bundled","streamUrl":"https://example.com/live.m3u8"}]}',
        'iptv_channels_timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      final prefs = await SharedPreferences.getInstance();
      final service = ChannelDataService(dio: Dio(), prefs: prefs);

      await expectLater(service.fetchChannels(), completion(isEmpty));
    });
  });
}
