import "package:feature_iptv/feature_iptv.dart";
import "package:platform_channels/platform_channels.dart";
import 'package:airo_app/features/media_hub/application/providers/discovery_provider.dart';
import 'package:airo_app/features/media_hub/domain/models/media_category.dart';
import 'package:airo_app/features/media_hub/domain/models/media_mode.dart';
import 'package:airo_app/features/music/application/providers/music_tracks_provider.dart';
import 'package:airo_app/features/music/domain/services/music_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps music tracks into unified discovery content', () async {
    const tracks = [
      MusicTrack(
        id: 'track-1',
        title: 'Track',
        artist: 'Artist',
        duration: Duration(minutes: 3),
        streamUrl: 'https://example.com/audio.mp3',
      ),
    ];
    final container = ProviderContainer(
      overrides: [
        musicTracksProvider.overrideWith((ref) async => tracks),
        mediaHubDiscoveryPageSizeProvider.overrideWith((ref) => 1),
      ],
    );
    addTearDown(container.dispose);

    final data = await container.read(
      mediaHubDiscoveryProvider(MediaMode.music).future,
    );

    expect(data.visibleItems, hasLength(1));
    expect(data.visibleItems.first.mode, MediaMode.music);
    expect(data.visibleItems.first.title, 'Track');
    expect(data.hasMore, isFalse);
  });

  test('maps tv channels into unified discovery content', () async {
    const channels = [
      IPTVChannel(
        id: 'tv-1',
        name: 'Airo TV',
        streamUrl: 'https://example.com/live.m3u8',
        group: 'General',
        category: ChannelCategory.general,
      ),
    ];
    final container = ProviderContainer(
      overrides: [iptvChannelsProvider.overrideWith((ref) async => channels)],
    );
    addTearDown(container.dispose);

    final data = await container.read(
      mediaHubDiscoveryProvider(MediaMode.tv).future,
    );

    expect(data.visibleItems, hasLength(1));
    expect(data.visibleItems.first.mode, MediaMode.tv);
    expect(data.visibleItems.first.title, 'Airo TV');
  });

  test('supports search, category filtering, and pagination', () async {
    final channels = [
      const IPTVChannel(
        id: 'tv-1',
        name: 'Airo News',
        streamUrl: 'https://example.com/news.m3u8',
        group: 'News',
        category: ChannelCategory.news,
      ),
      const IPTVChannel(
        id: 'tv-2',
        name: 'Airo Sports',
        streamUrl: 'https://example.com/sports.m3u8',
        group: 'Sports',
        category: ChannelCategory.sports,
      ),
      const IPTVChannel(
        id: 'tv-3',
        name: 'Airo Movies',
        streamUrl: 'https://example.com/movies.m3u8',
        group: 'Movies',
        category: ChannelCategory.movies,
      ),
    ];
    final container = ProviderContainer(
      overrides: [
        iptvChannelsProvider.overrideWith((ref) async => channels),
        mediaHubDiscoveryPageSizeProvider.overrideWith((ref) => 1),
      ],
    );
    addTearDown(container.dispose);

    final initial = await container.read(
      mediaHubDiscoveryProvider(MediaMode.tv).future,
    );
    expect(initial.visibleItems, hasLength(1));
    expect(initial.hasMore, isTrue);

    final notifier = container.read(
      mediaHubDiscoveryProvider(MediaMode.tv).notifier,
    );
    notifier.loadNextPage();
    final paged = container
        .read(mediaHubDiscoveryProvider(MediaMode.tv))
        .value!;
    expect(paged.visibleItems, hasLength(2));
    expect(paged.hasMore, isTrue);

    notifier.setCategory(MediaCategory.sports);
    final filtered = container
        .read(mediaHubDiscoveryProvider(MediaMode.tv))
        .value!;
    expect(filtered.visibleItems, hasLength(1));
    expect(filtered.visibleItems.first.title, 'Airo Sports');
    expect(filtered.hasMore, isFalse);

    notifier.setSearchQuery('movies');
    final searched = container
        .read(mediaHubDiscoveryProvider(MediaMode.tv))
        .value!;
    expect(searched.visibleItems, isEmpty);
    expect(searched.filteredCount, 0);
  });
}
