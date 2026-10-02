import 'package:feature_iptv/application/providers/iptv_providers.dart';
import 'package:feature_iptv/application/providers/vod_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_history/platform_history.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = IPTVChannel(
    id: 'news-1',
    name: 'News One',
    streamUrl: 'https://example.com/news.m3u8',
  );

  const vodItem = VodItem(
    id: 'movie-1',
    title: 'Movie One',
    streamUrl: 'https://example.com/movie.m3u8',
  );

  test('removeFromRecentlyWatchedProvider persists across container restart',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = RecentlyWatchedStorage(prefs);
    await storage.addToRecent(channel);

    var container = ProviderContainer(
      overrides: [
        recentlyWatchedStorageProvider.overrideWithValue(storage),
      ],
    );
    addTearDown(container.dispose);

    expect(await container.read(recentlyWatchedChannelsProvider.future), [channel]);
    await container.read(removeFromRecentlyWatchedProvider(channel.id).future);
    expect(await container.read(recentlyWatchedChannelsProvider.future), isEmpty);

    container = ProviderContainer(
      overrides: [
        recentlyWatchedStorageProvider.overrideWithValue(storage),
      ],
    );
    addTearDown(container.dispose);
    expect(await container.read(recentlyWatchedChannelsProvider.future), isEmpty);
  });

  test('removeFromVodContinueWatchingProvider clears history and resume', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final history = VodWatchHistoryStorage(prefs);
    final resume = VodResumePositionStorage(prefs);
    await history.addToRecent(vodItem);
    await resume.savePosition(
      VodResumePosition(
        channelId: vodItem.id,
        position: const Duration(minutes: 10),
        duration: const Duration(minutes: 90),
        updatedAt: DateTime.utc(2026, 1, 1),
      ),
    );

    final container = ProviderContainer(
      overrides: [
        vodWatchHistoryStorageProvider.overrideWithValue(history),
        vodResumePositionStorageProvider.overrideWithValue(resume),
      ],
    );
    addTearDown(container.dispose);

    await container.read(removeFromVodContinueWatchingProvider(vodItem.id).future);
    expect(await container.read(vodContinueWatchingEntriesProvider.future), isEmpty);
    expect(await resume.getPosition(vodItem.id), isNull);
  });
}
