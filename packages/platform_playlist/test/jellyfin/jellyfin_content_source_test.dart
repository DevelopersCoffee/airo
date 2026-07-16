import 'package:flutter_test/flutter_test.dart';
import 'package:platform_playlist/platform_playlist.dart';

class _FakeJellyfinClient implements JellyfinClient {
  _FakeJellyfinClient(this._channels);
  final List<JellyfinChannel> _channels;

  @override
  Future<JellyfinAuthResult> authenticate() async =>
      const JellyfinAuthResult(accessToken: 'jf-token', userId: 'user-1');

  @override
  Future<List<JellyfinChannel>> getLiveTvChannels({
    required String accessToken,
    required String userId,
  }) async => _channels;

  @override
  String streamUrl(String itemId, String accessToken) =>
      'https://jellyfin.example.com/Videos/$itemId/stream?api_key=$accessToken&static=true';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('JellyfinContentSource reports full capabilities', () {
    const source = JellyfinContentSource(
      id: 'jellyfin-1',
      label: 'My Jellyfin',
      serverUrl: 'https://jellyfin.example.com',
      credentialRef: ContentSourceCredentialRef('jellyfin-1'),
    );

    expect(source.kind, ContentSourceKind.jellyfin);
    expect(source.capabilities.hasEpg, isTrue);
    expect(source.capabilities.hasVod, isTrue);
  });

  test('adapter authenticates then maps channels via streamUrl', () async {
    final fakeClient = _FakeJellyfinClient([
      const JellyfinChannel(id: 'chan-1', name: 'News', number: '1'),
    ]);
    final adapter = JellyfinContentSourceAdapter(fakeClient);

    final channels = await adapter.loadChannels();

    expect(channels, hasLength(1));
    expect(channels.single.id, 'jellyfin-chan-1');
    expect(channels.single.name, 'News');
    expect(
      channels.single.streamUrl,
      'https://jellyfin.example.com/Videos/chan-1/stream?api_key=jf-token&static=true',
    );
  });
}
