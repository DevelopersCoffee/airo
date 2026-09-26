import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final coordinator = FavoriteReimportCoordinator();

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

  test('a favorite whose id still exists in the new list is kept as-is', () {
    final oldChannels = [channel(id: 'a1', name: 'BBC One', tvgId: 101)];
    final newChannels = [channel(id: 'a1', name: 'BBC One', tvgId: 101)];

    final result = coordinator.remapFavorites(
      favoriteChannelIds: {'a1'},
      oldChannels: oldChannels,
      newChannels: newChannels,
    );

    expect(result.remappedFavoriteIds, {'a1'});
    expect(result.needsReview, isEmpty);
  });

  test('a favorite whose stream URL is unchanged is remapped by identity', () {
    final oldChannels = [
      channel(
        id: 'a1',
        name: 'BBC One',
        streamUrl: 'https://cdn.example/bbc.m3u8',
      ),
    ];
    final newChannels = [
      channel(
        id: 'b9',
        name: 'Totally Different Label',
        streamUrl: 'https://cdn.example/bbc.m3u8',
      ),
    ];

    final result = coordinator.remapFavorites(
      favoriteChannelIds: {'a1'},
      oldChannels: oldChannels,
      newChannels: newChannels,
    );

    expect(result.remappedFavoriteIds, {'b9'});
    expect(result.needsReview, isEmpty);
  });

  test('tvg-id and name-only matches are ignored without the pro overlay', () {
    final oldChannels = [channel(id: 'a1', name: 'BBC One HD', tvgId: 101)];
    final newChannels = [
      channel(id: 'b9', name: 'bbc-one', tvgId: 101),
    ];

    final result = coordinator.remapFavorites(
      favoriteChannelIds: {'a1'},
      oldChannels: oldChannels,
      newChannels: newChannels,
    );

    expect(result.remappedFavoriteIds, isEmpty);
    expect(result.needsReview, isEmpty);
  });

  test('a favorite with no match anywhere is dropped, not carried forward', () {
    final oldChannels = [channel(id: 'a1', name: 'BBC One', tvgId: 101)];
    final newChannels = [
      channel(id: 'b9', name: 'CNN International', tvgId: 55),
    ];

    final result = coordinator.remapFavorites(
      favoriteChannelIds: {'a1'},
      oldChannels: oldChannels,
      newChannels: newChannels,
    );

    expect(result.remappedFavoriteIds, isEmpty);
    expect(result.needsReview, isEmpty);
  });

  test('non-favorited channels are ignored entirely', () {
    final oldChannels = [
      channel(
        id: 'a1',
        name: 'BBC One',
        streamUrl: 'https://cdn.example/bbc.m3u8',
      ),
      channel(id: 'a2', name: 'CNN International', tvgId: 55),
    ];
    final newChannels = [
      channel(
        id: 'b1',
        name: 'Renamed',
        streamUrl: 'https://cdn.example/bbc.m3u8',
      ),
      channel(id: 'b2', name: 'CNN Renamed', tvgId: 999),
    ];

    final result = coordinator.remapFavorites(
      favoriteChannelIds: {'a1'},
      oldChannels: oldChannels,
      newChannels: newChannels,
    );

    expect(result.remappedFavoriteIds, {'b1'});
    expect(result.needsReview, isEmpty);
  });
}
