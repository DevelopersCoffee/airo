import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  ProviderContainer buildContainer() {
    return ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
  }

  IPTVChannel channel({
    required String id,
    required String name,
    String? streamUrl,
    int? tvgId,
  }) {
    return IPTVChannel(
      id: id,
      name: name,
      streamUrl: streamUrl ?? 'https://example.com/$id.m3u8',
      tvgId: tvgId,
    );
  }

  test(
    'remaps a favorite via stream URL and writes the new id to storage',
    () async {
      final container = buildContainer();
      addTearDown(container.dispose);

      final storage = container.read(favoriteChannelsStorageProvider);
      await storage.setFavorite('a1');

      final needsReview = await applyFavoriteRemapOnReimport(
        favoriteStorage: storage,
        coordinator: FavoriteReimportCoordinator(),
        oldChannels: [
          channel(
            id: 'a1',
            name: 'BBC One',
            streamUrl: 'https://cdn.example/bbc.m3u8',
          ),
        ],
        newChannels: [
          channel(
            id: 'b9',
            name: 'Totally Different Label',
            streamUrl: 'https://cdn.example/bbc.m3u8',
          ),
        ],
      );

      expect(needsReview, isEmpty);
      final favoriteIds = await storage.getFavoriteChannelIds();
      expect(favoriteIds, {'b9'});
    },
  );

  test(
    'drops a tvg-id or name-only match instead of surfacing review on Play',
    () async {
      final container = buildContainer();
      addTearDown(container.dispose);

      final storage = container.read(favoriteChannelsStorageProvider);
      await storage.setFavorite('a1');

      final needsReview = await applyFavoriteRemapOnReimport(
        favoriteStorage: storage,
        coordinator: FavoriteReimportCoordinator(),
        oldChannels: [channel(id: 'a1', name: 'BBC One HD', tvgId: 101)],
        newChannels: [channel(id: 'b9', name: 'bbc-one', tvgId: 101)],
      );

      expect(needsReview, isEmpty);
      final favoriteIds = await storage.getFavoriteChannelIds();
      expect(favoriteIds, isEmpty);
    },
  );

  test('does nothing when there are no favorites', () async {
    final container = buildContainer();
    addTearDown(container.dispose);

    final storage = container.read(favoriteChannelsStorageProvider);

    final needsReview = await applyFavoriteRemapOnReimport(
      favoriteStorage: storage,
      coordinator: FavoriteReimportCoordinator(),
      oldChannels: [channel(id: 'a1', name: 'BBC One', tvgId: 101)],
      newChannels: [channel(id: 'b9', name: 'Renamed', tvgId: 101)],
    );

    expect(needsReview, isEmpty);
  });

  test('does nothing on the first import (no old channels yet)', () async {
    final container = buildContainer();
    addTearDown(container.dispose);

    final storage = container.read(favoriteChannelsStorageProvider);
    await storage.setFavorite('a1');

    final needsReview = await applyFavoriteRemapOnReimport(
      favoriteStorage: storage,
      coordinator: FavoriteReimportCoordinator(),
      oldChannels: const [],
      newChannels: [channel(id: 'b9', name: 'Renamed', tvgId: 101)],
    );

    expect(needsReview, isEmpty);
    final favoriteIds = await storage.getFavoriteChannelIds();
    expect(favoriteIds, {'a1'});
  });
}
