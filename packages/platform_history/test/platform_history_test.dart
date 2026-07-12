import 'package:flutter_test/flutter_test.dart';

import 'package:platform_channels/platform_channels.dart';
import 'package:platform_history/platform_history.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('persists recently watched channels', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = RecentlyWatchedStorage(prefs);

    const channel = IPTVChannel(
      id: 'news',
      name: 'News',
      streamUrl: 'https://example.com/news.m3u8',
    );

    await storage.addToRecent(channel);

    expect(await storage.getRecentlyWatched(), const [channel]);
  });
}
