import 'package:flutter_test/flutter_test.dart';
import 'package:platform_playlist/platform_playlist.dart';

class _FakeXtreamClient implements XtreamClient {
  _FakeXtreamClient(this._streams);
  final List<XtreamLiveStream> _streams;

  @override
  Future<List<XtreamLiveStream>> getLiveStreams() async => _streams;

  @override
  String liveStreamUrl(int streamId, {String extension = 'm3u8'}) =>
      'https://xtream.example.com/live/u/p/$streamId.$extension';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('XtreamContentSource reports full capabilities', () {
    const source = XtreamContentSource(
      id: 'xtream-1',
      label: 'My Xtream',
      serverUrl: 'https://xtream.example.com',
      credentialRef: ContentSourceCredentialRef('xtream-1'),
    );

    expect(source.kind, ContentSourceKind.xtream);
    expect(source.capabilities.hasEpg, isTrue);
    expect(source.capabilities.hasVod, isTrue);
  });

  test(
    'adapter maps XtreamLiveStream into IPTVChannel via live stream URL',
    () async {
      final fakeClient = _FakeXtreamClient([
        const XtreamLiveStream(
          streamId: 101,
          name: 'News HD',
          streamIcon: 'https://xtream.example.com/logo.png',
          categoryId: '5',
          epgChannelId: 'news.hd',
        ),
      ]);
      final adapter = XtreamContentSourceAdapter(fakeClient);

      final channels = await adapter.loadChannels();

      expect(channels, hasLength(1));
      expect(channels.single.name, 'News HD');
      expect(
        channels.single.streamUrl,
        'https://xtream.example.com/live/u/p/101.m3u8',
      );
      expect(channels.single.logoUrl, 'https://xtream.example.com/logo.png');
      expect(channels.single.id, 'xtream-101');
    },
  );
}
