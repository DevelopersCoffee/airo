import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final coordinator = FavoriteReimportCoordinator();

  IPTVChannel channel({required String id, required String name, int? tvgId}) {
    return IPTVChannel(
      id: id,
      name: name,
      streamUrl: 'https://example.com/$id.m3u8',
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

  test(
    'a favorite whose id changed is remapped via tvg-id with high confidence',
    () {
      final oldChannels = [channel(id: 'a1', name: 'BBC One', tvgId: 101)];
      final newChannels = [
        channel(id: 'b9', name: 'Totally Different Label', tvgId: 101),
      ];

      final result = coordinator.remapFavorites(
        favoriteChannelIds: {'a1'},
        oldChannels: oldChannels,
        newChannels: newChannels,
      );

      expect(result.remappedFavoriteIds, {'b9'});
      expect(result.needsReview, isEmpty);
    },
  );

  test(
    'a name-only match is not auto-remapped -- surfaced for review instead',
    () {
      final oldChannels = [channel(id: 'a1', name: 'BBC One HD')];
      final newChannels = [channel(id: 'b9', name: 'bbc-one')];

      final result = coordinator.remapFavorites(
        favoriteChannelIds: {'a1'},
        oldChannels: oldChannels,
        newChannels: newChannels,
      );

      expect(
        result.remappedFavoriteIds,
        isEmpty,
        reason: 'must not silently merge a low-confidence match',
      );
      expect(result.needsReview, hasLength(1));
      expect(result.needsReview.single.oldChannel.id, 'a1');
      expect(result.needsReview.single.candidate.id, 'b9');
    },
  );

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
      channel(id: 'a1', name: 'BBC One', tvgId: 101),
      channel(id: 'a2', name: 'CNN International', tvgId: 55),
    ];
    final newChannels = [
      channel(id: 'b1', name: 'Totally Different Label', tvgId: 101),
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

  test('handles multiple favorites independently', () {
    final oldChannels = [
      channel(id: 'a1', name: 'BBC One', tvgId: 101),
      channel(id: 'a2', name: 'BBC Two HD'),
    ];
    final newChannels = [
      channel(id: 'b1', name: 'Totally Different Label', tvgId: 101),
      channel(id: 'b2', name: 'bbc-two'),
    ];

    final result = coordinator.remapFavorites(
      favoriteChannelIds: {'a1', 'a2'},
      oldChannels: oldChannels,
      newChannels: newChannels,
    );

    expect(result.remappedFavoriteIds, {'b1'});
    expect(result.needsReview, hasLength(1));
    expect(result.needsReview.single.oldChannel.id, 'a2');
  });
}
