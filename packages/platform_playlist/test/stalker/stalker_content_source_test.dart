import 'package:flutter_test/flutter_test.dart';
import 'package:platform_playlist/platform_playlist.dart';

class _FakeStalkerClient implements StalkerClient {
  _FakeStalkerClient(this._channels);
  final List<StalkerChannel> _channels;
  String? tokenUsedForGetChannels;

  @override
  Future<String> handshake() async => 'tok-fake';

  @override
  Future<List<StalkerChannel>> getChannels({required String token}) async {
    tokenUsedForGetChannels = token;
    return _channels;
  }

  @override
  Future<String> createLink({required String token, required String cmd}) async =>
      'https://stalker.example.com/resolved/$cmd';

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

void main() {
  test('StalkerContentSource reports EPG-capable, no VOD', () {
    const source = StalkerContentSource(
      id: 'stalker-1',
      label: 'My Stalker Portal',
      serverUrl: 'https://stalker.example.com',
      macAddress: 'AA:BB:CC:DD:EE:FF',
    );

    expect(source.kind, ContentSourceKind.stalker);
    expect(source.capabilities.hasEpg, isTrue);
    expect(source.capabilities.hasVod, isFalse);
  });

  test('adapter handshakes then resolves each channel link', () async {
    final fakeClient = _FakeStalkerClient([
      const StalkerChannel(
        id: '1',
        name: 'Sports 1',
        cmd: 'ffmpeg http://localhost/ch/1_',
        logo: 'https://stalker.example.com/logo1.png',
      ),
    ]);
    final adapter = StalkerContentSourceAdapter(fakeClient);

    final channels = await adapter.loadChannels();

    expect(channels, hasLength(1));
    expect(channels.single.id, 'stalker-1');
    expect(channels.single.name, 'Sports 1');
    expect(
      channels.single.streamUrl,
      'https://stalker.example.com/resolved/ffmpeg http://localhost/ch/1_',
    );
    expect(fakeClient.tokenUsedForGetChannels, 'tok-fake');
  });
}
