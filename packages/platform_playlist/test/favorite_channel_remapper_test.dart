import 'package:flutter_test/flutter_test.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_playlist/platform_playlist.dart';

void main() {
  final remapper = FavoriteChannelRemapper();

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

  test('auto-matches a favorite when the stream URL is unchanged', () {
    final favorite = channel(
      id: 'a1',
      name: 'BBC One',
      streamUrl: 'https://cdn.example/bbc.m3u8',
    );
    final providerBCandidates = [
      channel(id: 'b1', name: 'CNN International'),
      channel(
        id: 'b2',
        name: 'Totally Different Label',
        streamUrl: 'https://cdn.example/bbc.m3u8',
      ),
    ];

    final result = remapper.findMatch(favorite, providerBCandidates);

    expect(result.channel?.id, 'b2');
    expect(result.needsReview, isFalse);
  });

  test('does not remap on tvg-id or name alone in the public Play remapper', () {
    final favorite = channel(id: 'a1', name: 'BBC One HD', tvgId: 101);
    final providerBCandidates = [
      channel(id: 'b1', name: 'bbc-one', tvgId: 101),
    ];

    final result = remapper.findMatch(favorite, providerBCandidates);

    expect(result.channel, isNull);
    expect(result.needsReview, isFalse);
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

  test('empty candidate list yields no match', () {
    final favorite = channel(id: 'a1', name: 'BBC One', tvgId: 101);

    final result = remapper.findMatch(favorite, const []);

    expect(result.channel, isNull);
    expect(result.needsReview, isFalse);
  });
}
