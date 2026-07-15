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

  test(
    'keeps the most recent channels within the bounded history size',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = RecentlyWatchedStorage(prefs);

      for (var i = 0; i < 25; i++) {
        await storage.addToRecent(
          IPTVChannel(
            id: 'channel-$i',
            name: 'Channel $i',
            streamUrl: 'https://example.com/$i.m3u8',
          ),
        );
      }

      final recent = await storage.getRecentlyWatched();

      expect(recent, hasLength(20));
      expect(recent.first.id, 'channel-24');
      expect(recent.last.id, 'channel-5');
    },
  );

  test(
    'rejects oversized recent-history JSON at the preference boundary',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = RecentlyWatchedStorage(
        prefs,
        maxPreferenceValueBytes: 96,
      );

      await storage.addToRecent(
        const IPTVChannel(
          id: 'large-channel',
          name:
              'Large Channel Name That Makes The Encoded Recent History Too Large',
          streamUrl: 'https://example.com/large-channel.m3u8',
        ),
      );

      expect(await storage.getRecentlyWatched(), isEmpty);
      expect(prefs.getString('iptv_recently_watched'), isNull);
    },
  );

  test('clears recent history through the guarded store', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = RecentlyWatchedStorage(prefs);

    await storage.addToRecent(
      const IPTVChannel(
        id: 'news',
        name: 'News',
        streamUrl: 'https://example.com/news.m3u8',
      ),
    );
    expect(await storage.getRecentCount(), 1);

    await storage.clearRecent();

    expect(await storage.getRecentlyWatched(), isEmpty);
    expect(storage.hasRecentlyWatched(), isFalse);
  });
}
