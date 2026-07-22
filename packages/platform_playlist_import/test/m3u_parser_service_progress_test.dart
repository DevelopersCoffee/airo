import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_playlist_import/platform_playlist_import.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Covers `M3UParserService.fetchPlaylistWithProgress`, the staged-import
/// wrapper around the real `fetchPlaylist`/`_fetchAndParse`/`_loadFromCache`/
/// `_saveToCache` flow (see `M3UParserService BYOC source` group in
/// `platform_playlist_import_test.dart` for the equivalent one-shot
/// coverage). Uses the same real-`HttpServer` seam as that file rather than
/// a fake Dio adapter, since this package's existing tests already exercise
/// caching/HTTP-validator behavior that way.
void main() {
  late SharedPreferences prefs;
  late Directory cacheDir;
  late M3UParserService parser;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    cacheDir = await Directory.systemTemp.createTemp(
      'm3u_parser_service_progress_test_',
    );
    addTearDown(() async {
      if (cacheDir.existsSync()) {
        await cacheDir.delete(recursive: true);
      }
    });
    parser = M3UParserService(
      dio: Dio(),
      prefs: prefs,
      cacheDirectoryProvider: () async => cacheDir,
      downloadDirectoryProvider: () async => cacheDir,
    );
  });

  group('fetchPlaylistWithProgress', () {
    test('no playlist URL configured fails validation before download', () async {
      final emissions = await parser.fetchPlaylistWithProgress().toList();
      final stages = emissions.map((e) => e.stage).toList();

      expect(stages, [ImportStage.import_, ImportStage.failed]);
      expect(emissions.last.error, isNotNull);
    });

    test(
      'successful fresh fetch proceeds through every stage in order and '
      'ends ready with a channel count',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() => server.close(force: true));
        server.listen((request) async {
          request.response.write('''
#EXTM3U
#EXTINF:-1 group-title="News",Progress News
https://cdn.example.com/progress-news.m3u8
#EXTINF:-1 group-title="News",Progress News
https://cdn.example.com/progress-news.m3u8
''');
          await request.response.close();
        });

        await parser.setPlaylistUrl(
          'http://${server.address.address}:${server.port}/playlist.m3u',
        );

        final emissions = await parser.fetchPlaylistWithProgress().toList();
        final stages = emissions.map((e) => e.stage).toList();

        expect(stages, [
          ImportStage.import_,
          ImportStage.validate,
          ImportStage.download,
          ImportStage.parse,
          ImportStage.normalize,
          ImportStage.deduplicate,
          ImportStage.indexing,
          ImportStage.generateRails,
          ImportStage.persist,
          ImportStage.ready,
        ]);

        final ready = emissions.last;
        expect(ready.error, isNull);
        // Two identical #EXTINF entries dedupe to a single channel.
        expect(ready.message, contains('1'));
      },
    );

    test(
      'network failure during download emits failed and never reaches ready',
      () async {
        // Bind then immediately close so the port is refusing connections.
        final deadServer = await HttpServer.bind(
          InternetAddress.loopbackIPv4,
          0,
        );
        final deadPort = deadServer.port;
        await deadServer.close(force: true);

        await parser.setPlaylistUrl(
          'http://${InternetAddress.loopbackIPv4.address}:$deadPort/playlist.m3u',
        );

        final emissions = await parser.fetchPlaylistWithProgress().toList();
        final stages = emissions.map((e) => e.stage).toList();

        expect(stages.first, ImportStage.import_);
        expect(stages, contains(ImportStage.download));
        expect(stages.last, ImportStage.failed);
        expect(stages, isNot(contains(ImportStage.ready)));
        expect(emissions.last.error, isNotNull);
      },
    );

    test(
      'cache hit with forceRefresh false collapses to a fast path and '
      'still reaches ready',
      () async {
        var requestCount = 0;
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() => server.close(force: true));
        server.listen((request) async {
          requestCount++;
          request.response.write('''
#EXTM3U
#EXTINF:-1 group-title="News",Cached News
https://cdn.example.com/cached-news.m3u8
''');
          await request.response.close();
        });

        await parser.setPlaylistUrl(
          'http://${server.address.address}:${server.port}/playlist.m3u',
        );

        // Prime the cache via the real one-shot fetch path.
        final primed = await parser.fetchPlaylist(forceRefresh: true);
        expect(primed, hasLength(1));
        expect(requestCount, 1);

        final emissions = await parser
            .fetchPlaylistWithProgress(forceRefresh: false)
            .toList();
        final stages = emissions.map((e) => e.stage).toList();

        // No new HTTP request for the cache-hit path.
        expect(requestCount, 1);
        expect(stages, [
          ImportStage.import_,
          ImportStage.validate,
          ImportStage.indexing,
          ImportStage.generateRails,
          ImportStage.persist,
          ImportStage.ready,
        ]);
        expect(stages, isNot(contains(ImportStage.download)));

        final ready = emissions.last;
        expect(ready.error, isNull);
        expect(ready.message, contains('1'));
      },
    );
  });

  group('fetchPlaylist (existing one-shot API, must keep working)', () {
    test('still returns no channels when no playlist URL is configured', () async {
      await expectLater(parser.fetchPlaylist(), completion(isEmpty));
    });
  });
}
