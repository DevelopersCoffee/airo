import 'package:flutter_test/flutter_test.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_playlist/platform_playlist.dart';
import 'package:platform_playlist_import/platform_playlist_import.dart';

class _FakeM3UParserService implements M3UParserService {
  _FakeM3UParserService(this._channels);

  final List<IPTVChannel> _channels;
  int fetchCallCount = 0;

  @override
  Future<List<IPTVChannel>> fetchPlaylist({bool forceRefresh = false}) async {
    fetchCallCount++;
    return _channels;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

void main() {
  test('M3uContentSource reports m3u kind and EPG-only capabilities', () {
    const source = M3uContentSource(
      id: 'm3u-1',
      label: 'My Playlist',
      playlistUrl: 'https://example.com/playlist.m3u',
    );

    expect(source.kind, ContentSourceKind.m3u);
    expect(source.capabilities.hasVod, isFalse);
    expect(source.capabilities.hasCatchup, isFalse);
  });

  test('adapter delegates straight to M3UParserService.fetchPlaylist', () async {
    final channel = IPTVChannel.fromM3U(name: 'Test', url: 'https://x/stream.m3u8');
    final fakeParser = _FakeM3UParserService([channel]);
    const source = M3uContentSource(
      id: 'm3u-1',
      label: 'My Playlist',
      playlistUrl: 'https://example.com/playlist.m3u',
    );
    final adapter = M3uContentSourceAdapter(source, fakeParser);

    final result = await adapter.loadChannels();

    expect(result, [channel]);
    expect(fakeParser.fetchCallCount, 1);
  });

  test('adapter forwards forceRefresh unchanged', () async {
    final fakeParser = _FakeM3UParserService(const []);
    const source = M3uContentSource(
      id: 'm3u-1',
      label: 'My Playlist',
      playlistUrl: 'https://example.com/playlist.m3u',
    );
    final adapter = M3uContentSourceAdapter(source, fakeParser);

    await adapter.loadChannels(forceRefresh: true);

    expect(fakeParser.fetchCallCount, 1);
  });
}
