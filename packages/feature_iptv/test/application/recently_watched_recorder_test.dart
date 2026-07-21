import 'dart:async';

import 'package:feature_iptv/application/providers/iptv_providers.dart';
import 'package:feature_iptv/application/providers/recently_watched_recorder.dart';
import 'package:feature_iptv/application/providers/vod_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_history/platform_history.dart';
import 'package:platform_player/platform_player.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const channelA = IPTVChannel(
    id: 'chan-a',
    name: 'Channel A',
    streamUrl: 'https://example.com/a.m3u8',
  );
  const channelB = IPTVChannel(
    id: 'chan-b',
    name: 'Channel B',
    streamUrl: 'https://example.com/b.m3u8',
  );
  const vodItem = VodItem(
    id: 'vod-1',
    title: 'Test Movie',
    streamUrl: 'https://example.com/movie.mp4',
    group: 'Movies',
    kind: VodContentKind.movie,
  );
  // VOD plays through a synthetic IPTVChannel with the same id (see
  // vod_screen.dart's _selectItem).
  const vodSyntheticChannel = IPTVChannel(
    id: 'vod-1',
    name: 'Test Movie',
    streamUrl: 'https://example.com/movie.mp4',
  );

  late StreamController<StreamingState> states;
  late RecentlyWatchedStorage liveStorage;
  late VodWatchHistoryStorage vodStorage;
  late ProviderContainer container;

  StreamingState stateFor(IPTVChannel channel, PlaybackState playback) {
    return StreamingState(currentChannel: channel, playbackState: playback);
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    liveStorage = RecentlyWatchedStorage(prefs);
    vodStorage = VodWatchHistoryStorage(prefs);
    states = StreamController<StreamingState>.broadcast();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        recentlyWatchedStorageProvider.overrideWithValue(liveStorage),
        vodWatchHistoryStorageProvider.overrideWithValue(vodStorage),
        streamingStateStreamProvider.overrideWithValue(states.stream),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await states.close();
    });
    // Activate the recorder (in the app, VideoPlayerWidget watches it).
    container.read(recentlyWatchedRecorderProvider);
  });

  test(
    'a channel that fails to start is NOT added to recently watched',
    () async {
      states.add(stateFor(channelA, PlaybackState.loading));
      states.add(stateFor(channelA, PlaybackState.error));
      await Future<void>.delayed(Duration.zero);

      expect(await liveStorage.getRecentlyWatched(), isEmpty);
    },
  );

  test('a channel is recorded once playback actually starts', () async {
    states.add(stateFor(channelA, PlaybackState.loading));
    states.add(stateFor(channelA, PlaybackState.playing));
    await Future<void>.delayed(Duration.zero);

    final recent = await liveStorage.getRecentlyWatched();
    expect(recent.map((c) => c.id), ['chan-a']);
  });

  test('failed-then-successful play records only after the success', () async {
    states.add(stateFor(channelA, PlaybackState.loading));
    states.add(stateFor(channelA, PlaybackState.error));
    await Future<void>.delayed(Duration.zero);
    expect(await liveStorage.getRecentlyWatched(), isEmpty);

    states.add(stateFor(channelA, PlaybackState.loading));
    states.add(stateFor(channelA, PlaybackState.playing));
    await Future<void>.delayed(Duration.zero);

    expect((await liveStorage.getRecentlyWatched()).map((c) => c.id), [
      'chan-a',
    ]);
  });

  test('switching channels records each newly playing channel', () async {
    states.add(stateFor(channelA, PlaybackState.playing));
    states.add(stateFor(channelB, PlaybackState.loading));
    states.add(stateFor(channelB, PlaybackState.playing));
    await Future<void>.delayed(Duration.zero);

    expect((await liveStorage.getRecentlyWatched()).map((c) => c.id), [
      'chan-b',
      'chan-a',
    ]);
  });

  test(
    'a pending VOD item lands in VOD history, not live recently watched',
    () async {
      container.read(pendingVodHistoryItemProvider.notifier).state = vodItem;

      states.add(stateFor(vodSyntheticChannel, PlaybackState.loading));
      states.add(stateFor(vodSyntheticChannel, PlaybackState.playing));
      await Future<void>.delayed(Duration.zero);

      expect(await vodStorage.getRecentlyWatched(), hasLength(1));
      expect((await vodStorage.getRecentlyWatched()).single.id, 'vod-1');
      expect(await liveStorage.getRecentlyWatched(), isEmpty);
      // Pending marker consumed.
      expect(container.read(pendingVodHistoryItemProvider), isNull);
    },
  );

  test('a failed VOD play leaves the pending item unrecorded', () async {
    container.read(pendingVodHistoryItemProvider.notifier).state = vodItem;

    states.add(stateFor(vodSyntheticChannel, PlaybackState.loading));
    states.add(stateFor(vodSyntheticChannel, PlaybackState.error));
    await Future<void>.delayed(Duration.zero);

    expect(await vodStorage.getRecentlyWatched(), isEmpty);
    expect(await liveStorage.getRecentlyWatched(), isEmpty);
  });
}
