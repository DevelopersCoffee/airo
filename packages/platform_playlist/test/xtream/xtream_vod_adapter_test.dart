import 'package:flutter_test/flutter_test.dart';
import 'package:platform_playlist/platform_playlist.dart';

class _FakeXtreamClient implements XtreamClient {
  _FakeXtreamClient(this._streams);
  final List<XtreamVodStream> _streams;

  @override
  Future<List<XtreamVodStream>> getVodStreams() async => _streams;

  @override
  String vodStreamUrl(int streamId, String containerExtension) =>
      'https://xtream.example.com/movie/u/p/$streamId.$containerExtension';

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

void main() {
  test('maps XtreamVodStream into VodItem with movie kind, no seriesRef', () async {
    final fakeClient = _FakeXtreamClient([
      const XtreamVodStream(
        streamId: 501,
        name: 'Example Movie',
        streamIcon: 'https://xtream.example.com/poster.jpg',
        categoryId: '10',
        containerExtension: 'mp4',
      ),
    ]);
    final adapter = XtreamVodAdapter(fakeClient);

    final items = await adapter.loadVodItems();

    expect(items, hasLength(1));
    expect(items.single.id, 'xtream-vod-501');
    expect(items.single.title, 'Example Movie');
    expect(items.single.streamUrl, 'https://xtream.example.com/movie/u/p/501.mp4');
    expect(items.single.posterUrl, 'https://xtream.example.com/poster.jpg');
    expect(items.single.kind, VodContentKind.movie);
    expect(items.single.seriesRef, isNull);
    expect(items.single.containerExtension, 'mp4');
  });

  test('defaults containerExtension to mp4 when the source omits it', () async {
    final fakeClient = _FakeXtreamClient([
      const XtreamVodStream(streamId: 502, name: 'No Extension Movie'),
    ]);
    final adapter = XtreamVodAdapter(fakeClient);

    final items = await adapter.loadVodItems();

    expect(items.single.streamUrl, 'https://xtream.example.com/movie/u/p/502.mp4');
    expect(items.single.containerExtension, 'mp4');
  });

  test('empty VOD list from source yields empty result', () async {
    final adapter = XtreamVodAdapter(_FakeXtreamClient(const []));

    final items = await adapter.loadVodItems();

    expect(items, isEmpty);
  });
}
