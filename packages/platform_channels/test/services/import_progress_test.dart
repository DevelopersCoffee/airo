import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fake adapter returning a fixed plain-text body (or throwing) regardless of
/// the requested URL, mirroring the seam used by the Xtream/Stalker/Jellyfin
/// client tests in `platform_playlist` (`FakeHttpClientAdapter`): a Dio is
/// constructed normally and its `httpClientAdapter` is swapped for a fake, so
/// the service under test never touches the network.
class _FakePlaylistAdapter implements HttpClientAdapter {
  _FakePlaylistAdapter.body(this._body) : _error = null;
  _FakePlaylistAdapter.failing(this._error) : _body = null;

  final String? _body;
  final Object? _error;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (_error != null) {
      throw DioException(requestOptions: options, error: _error);
    }
    return ResponseBody.fromBytes(utf8.encode(_body!), 200);
  }

  @override
  void close({bool force = false}) {}
}

Dio _dioReturning(String body) {
  final dio = Dio();
  dio.httpClientAdapter = _FakePlaylistAdapter.body(body);
  return dio;
}

Dio _dioFailing(Object error) {
  final dio = Dio();
  dio.httpClientAdapter = _FakePlaylistAdapter.failing(error);
  return dio;
}

const _samplePlaylist = '''
#EXTM3U
#EXTINF:-1,News One
https://example.com/news-one.m3u8
#EXTINF:-1,Sports One
https://example.com/sports-one.m3u8
#EXTINF:-1,News One Again
https://example.com/news-one.m3u8
''';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('ChannelDataService.importPlaylist', () {
    test('emits the staged sequence and ends ready with a channel count', () async {
      final service = ChannelDataService(
        dio: _dioReturning(_samplePlaylist),
        prefs: prefs,
      );

      final emissions = await service
          .importPlaylist('https://cdn.example.com/playlist.m3u8')
          .toList();

      final stages = emissions.map((e) => e.stage).toList();

      expect(
        stages.take(4),
        [
          ImportStage.import_,
          ImportStage.validate,
          ImportStage.download,
          ImportStage.parse,
        ],
      );
      expect(stages.last, ImportStage.ready);
      expect(stages, isNot(contains(ImportStage.failed)));

      final ready = emissions.last;
      expect(ready.error, isNull);
      // 3 entries in the fixture dedupe to 2 unique stream URLs.
      expect(ready.message, contains('2'));
    });

    test(
      'malformed playlist URL fails validation, never downloads, never reaches ready',
      () async {
        final service = ChannelDataService(
          dio: _dioReturning(_samplePlaylist),
          prefs: prefs,
        );

        final emissions = await service
            .importPlaylist('not-a-valid-url')
            .toList();

        final stages = emissions.map((e) => e.stage).toList();

        expect(stages.first, ImportStage.import_);
        expect(stages.last, ImportStage.failed);
        expect(stages, isNot(contains(ImportStage.download)));
        expect(stages, isNot(contains(ImportStage.ready)));
        expect(emissions.last.error, isNotNull);
      },
    );

    test(
      'network failure during download fails the pipeline without ready',
      () async {
        final service = ChannelDataService(
          dio: _dioFailing('connection refused'),
          prefs: prefs,
        );

        final emissions = await service
            .importPlaylist('https://cdn.example.com/playlist.m3u8')
            .toList();

        final stages = emissions.map((e) => e.stage).toList();

        expect(stages, [
          ImportStage.import_,
          ImportStage.validate,
          ImportStage.failed,
        ]);
        expect(stages, isNot(contains(ImportStage.ready)));
        expect(emissions.last.error, isNotNull);
      },
    );
  });

  group('ChannelDataService.fetchChannels (existing one-shot API)', () {
    test('still returns no first-party channels', () async {
      final service = ChannelDataService(
        dio: _dioReturning(_samplePlaylist),
        prefs: prefs,
      );

      await expectLater(service.fetchChannels(), completion(isEmpty));
    });
  });
}
