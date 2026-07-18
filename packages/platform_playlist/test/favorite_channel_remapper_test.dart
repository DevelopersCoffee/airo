import 'package:flutter_test/flutter_test.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_playlist/platform_playlist.dart';

void main() {
  final remapper = FavoriteChannelRemapper();

  IPTVChannel channel({required String id, required String name, int? tvgId}) {
    return IPTVChannel(
      id: id,
      name: name,
      streamUrl: 'https://example.com/$id.m3u8',
      tvgId: tvgId,
    );
  }

  test('auto-matches a favorite to its Provider B counterpart via tvg-id', () {
    final favorite = channel(id: 'a1', name: 'BBC One', tvgId: 101);
    final providerBCandidates = [
      channel(id: 'b1', name: 'CNN International', tvgId: 55),
      channel(id: 'b2', name: 'Totally Different Label', tvgId: 101),
    ];

    final result = remapper.findMatch(favorite, providerBCandidates);

    expect(result.channel?.id, 'b2');
    expect(result.needsReview, isFalse);
  });

  test('flags a name-only match for review instead of auto-merging', () {
    final favorite = channel(id: 'a1', name: 'BBC One HD');
    final providerBCandidates = [channel(id: 'b1', name: 'bbc-one')];

    final result = remapper.findMatch(favorite, providerBCandidates);

    expect(result.channel?.id, 'b1');
    expect(result.needsReview, isTrue);
  });

  test('finds no match when nothing corresponds', () {
    final favorite = channel(id: 'a1', name: 'BBC One', tvgId: 101);
    final providerBCandidates = [
      channel(id: 'b1', name: 'CNN International', tvgId: 55),
    ];

    final result = remapper.findMatch(favorite, providerBCandidates);

    expect(result.channel, isNull);
    expect(result.needsReview, isFalse);
  });

  test(
    'prefers the highest-confidence candidate when several are plausible',
    () {
      final favorite = channel(id: 'a1', name: 'BBC One', tvgId: 101);
      final providerBCandidates = [
        // Name-only match (medium) -- should lose to the tvg-id match (high).
        channel(id: 'b1', name: 'BBC One'),
        channel(id: 'b2', name: 'Totally Different Label', tvgId: 101),
      ];

      final result = remapper.findMatch(favorite, providerBCandidates);

      expect(result.channel?.id, 'b2');
      expect(result.needsReview, isFalse);
    },
  );

  test('empty candidate list yields no match', () {
    final favorite = channel(id: 'a1', name: 'BBC One', tvgId: 101);

    final result = remapper.findMatch(favorite, const []);

    expect(result.channel, isNull);
    expect(result.needsReview, isFalse);
  });
}
