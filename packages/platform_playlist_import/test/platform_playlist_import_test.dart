import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_playlist_import/platform_playlist_import.dart';
import 'package:platform_worker_jobs/platform_worker_jobs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('parses M3U channel entries', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final parser = M3UParserService(dio: Dio(), prefs: prefs);

    final channels = parser.parseM3U('''
#EXTM3U
#EXTINF:-1 group-title="News",News One
https://example.com/news.m3u8
''');

    expect(channels, hasLength(1));
    expect(channels.single.name, 'News One');
    expect(channels.single.streamUrl, 'https://example.com/news.m3u8');
  });

  test('parses M3U channel entries through default worker executor', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final parser = M3UParserService(dio: Dio(), prefs: prefs);

    final channels = await parser.parseM3UOffMain('''
#EXTM3U
#EXTINF:-1 group-title="News",Worker One
https://example.com/worker.m3u8
''');

    expect(channels, hasLength(1));
    expect(channels.single.name, 'Worker One');
    expect(channels.single.streamUrl, 'https://example.com/worker.m3u8');
  });

  group('M3UParserService deduplication', () {
    late M3UParserService parser;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      parser = M3UParserService(dio: Dio(), prefs: prefs);
    });

    test('deduplicates normalized channel names and prefers logo entries', () {
      final channels = parser.parseM3U('''
#EXTM3U
#EXTINF:-1 group-title="News",News One
https://example.com/news-no-logo.m3u8
#EXTINF:-1 tvg-logo="https://example.com/news.png" group-title="News", news-one
https://example.com/news-logo.m3u8
''');

      expect(channels, hasLength(1));
      expect(channels.single.name, 'News-one');
      expect(channels.single.logoUrl, 'https://example.com/news.png');
      expect(channels.single.streamUrl, 'https://example.com/news-logo.m3u8');
    });

    test('keeps logo-preferred dedup output stable when order changes', () {
      final logoFirst = parser.parseM3U('''
#EXTM3U
#EXTINF:-1 tvg-logo="https://example.com/sports.png",SPORTS 24
https://example.com/sports-logo.m3u8
#EXTINF:-1,sports-24
https://example.com/sports-no-logo.m3u8
''');

      final logoSecond = parser.parseM3U('''
#EXTM3U
#EXTINF:-1,sports-24
https://example.com/sports-no-logo.m3u8
#EXTINF:-1 tvg-logo="https://example.com/sports.png",SPORTS 24
https://example.com/sports-logo.m3u8
''');

      expect(logoFirst, hasLength(1));
      expect(logoSecond, hasLength(1));
      expect(logoFirst.single.name, logoSecond.single.name);
      expect(logoFirst.single.logoUrl, logoSecond.single.logoUrl);
      expect(logoFirst.single.streamUrl, logoSecond.single.streamUrl);
    });

    test('collapses display whitespace without lowercasing short acronyms', () {
      final channels = parser.parseM3U('''
#EXTM3U
#EXTINF:-1,  BBC    WORLD   news
https://example.com/bbc-world-news.m3u8
''');

      expect(channels.single.name, 'BBC World News');
    });
  });

  group('M3UParserService URL policy', () {
    late M3UParserService parser;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      parser = M3UParserService(dio: Dio(), prefs: prefs);
    });

    test('drops forbidden stream URLs and strips forbidden logo URLs', () {
      final channels = parser.parseM3U('''
#EXTM3U
#EXTINF:-1,Local File
file:///etc/passwd
#EXTINF:-1,Private Host
http://192.168.1.1/live.m3u8
#EXTINF:-1,Script
javascript:alert(1)
#EXTINF:-1 tvg-logo="file:///private/logo.png",Public Stream
https://cdn.example.com/live.m3u8
''');

      expect(channels, hasLength(1));
      expect(channels.single.name, 'Public Stream');
      expect(channels.single.streamUrl, 'https://cdn.example.com/live.m3u8');
      expect(channels.single.logoUrl, isNull);
    });
  });

  group('M3UParserService BYOC source', () {
    late SharedPreferences prefs;
    late M3UParserService parser;
    late Directory cacheDir;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      cacheDir = await Directory.systemTemp.createTemp(
        'platform_playlist_import_test_',
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
      );
    });

    test(
      'returns no channels when no user playlist URL is configured',
      () async {
        await expectLater(parser.fetchPlaylist(), completion(isEmpty));
        expect(parser.getPlaylistUrl(), isNull);
      },
    );

    test('rejects empty and non-http playlist URLs', () async {
      expect(() => parser.setPlaylistUrl(''), throwsArgumentError);
      expect(
        () => parser.setPlaylistUrl('file:///private/playlist.m3u'),
        throwsArgumentError,
      );
      expect(
        () => parser.setPlaylistUrl('ftp://example.com/playlist.m3u'),
        throwsArgumentError,
      );
    });

    test('persists valid http and https playlist URLs', () async {
      await parser.setPlaylistUrl('https://example.com/playlist.m3u');
      expect(parser.getPlaylistUrl(), 'https://example.com/playlist.m3u');

      await parser.setPlaylistUrl('http://example.com/playlist.m3u');
      expect(parser.getPlaylistUrl(), 'http://example.com/playlist.m3u');
    });

    test('rejects oversized playlist URLs before persisting', () async {
      parser = M3UParserService(
        dio: Dio(),
        prefs: prefs,
        cacheDirectoryProvider: () async => cacheDir,
        maxPreferenceValueBytes: 32,
      );

      await expectLater(
        parser.setPlaylistUrl('https://example.com/${'x' * 64}.m3u'),
        throwsA(isA<Exception>()),
      );

      expect(parser.getPlaylistUrl(), isNull);
      expect(prefs.getString('iptv_user_playlist_url'), isNull);
    });

    test('clears playlist URL and user-derived cache', () async {
      await parser.setPlaylistUrl('https://example.com/playlist.m3u');
      await parser.clearPlaylist();

      expect(parser.getPlaylistUrl(), isNull);
      await expectLater(parser.fetchPlaylist(), completion(isEmpty));
    });

    test(
      'parses async fetch and 304 cache paths through worker executor',
      () async {
        final workerExecutor = _RecordingWorkerExecutor();
        parser = M3UParserService(
          dio: Dio(),
          prefs: prefs,
          cacheDirectoryProvider: () async => cacheDir,
          workerExecutor: workerExecutor,
        );

        final requests = <HttpHeaders>[];
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() => server.close(force: true));

        server.listen((request) async {
          requests.add(request.headers);
          request.response.headers
            ..set(HttpHeaders.etagHeader, '"worker-playlist-v1"')
            ..set(
              HttpHeaders.lastModifiedHeader,
              'Wed, 21 Oct 2015 07:28:00 GMT',
            );

          if (requests.length == 1) {
            request.response.write('''
#EXTM3U
#EXTINF:-1 group-title="News",Worker News
https://cdn.example.com/worker-news.m3u8
''');
          } else {
            request.response.statusCode = HttpStatus.notModified;
          }
          await request.response.close();
        });

        await parser.setPlaylistUrl(
          'http://${server.address.address}:${server.port}/playlist.m3u',
        );

        final initial = await parser.fetchPlaylist(forceRefresh: true);
        final cached = await parser.fetchPlaylist(forceRefresh: true);

        expect(initial.single.name, 'Worker News');
        expect(
          cached.single.streamUrl,
          'https://cdn.example.com/worker-news.m3u8',
        );
        expect(workerExecutor.calls, 3);
        expect(workerExecutor.kinds, [
          AiroWorkerJobKind.playlistImport,
          AiroWorkerJobKind.playlistImport,
          AiroWorkerJobKind.playlistImport,
        ]);
        expect(workerExecutor.debugNames, [
          'm3u_playlist_parse',
          'm3u_playlist_cache_encode',
          'm3u_playlist_cache_decode',
        ]);
      },
    );

    test('stores structured cache and reads it without M3U reparse', () async {
      final workerExecutor = _RecordingWorkerExecutor();
      parser = M3UParserService(
        dio: Dio(),
        prefs: prefs,
        cacheDirectoryProvider: () async => cacheDir,
        workerExecutor: workerExecutor,
      );

      var requestCount = 0;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));

      server.listen((request) async {
        requestCount++;
        request.response.write('''
#EXTM3U
#EXTINF:-1 group-title="News",Structured News
https://cdn.example.com/structured-news.m3u8
''');
        await request.response.close();
      });

      await parser.setPlaylistUrl(
        'http://${server.address.address}:${server.port}/playlist.m3u',
      );

      final initial = await parser.fetchPlaylist(forceRefresh: true);
      final cached = await parser.fetchPlaylist();

      final cacheFile = File('${cacheDir.path}/iptv_channel_cache.json');
      final payload = jsonDecode(await cacheFile.readAsString());

      expect(initial.single.name, 'Structured News');
      expect(cached.single.streamUrl, initial.single.streamUrl);
      expect(requestCount, 1);
      expect(prefs.getString('iptv_playlist_cache'), isNull);
      expect(cacheFile.existsSync(), isTrue);
      expect(payload, isA<Map<String, dynamic>>());
      expect(payload['channels'], isA<List<dynamic>>());
      expect(workerExecutor.debugNames, [
        'm3u_playlist_parse',
        'm3u_playlist_cache_encode',
        'm3u_playlist_cache_decode',
      ]);
    });

    test('uses HTTP validators and cached playlist on 304 refresh', () async {
      final requests = <HttpHeaders>[];
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));

      server.listen((request) async {
        requests.add(request.headers);
        request.response.headers
          ..set(HttpHeaders.etagHeader, '"playlist-v1"')
          ..set(
            HttpHeaders.lastModifiedHeader,
            'Wed, 21 Oct 2015 07:28:00 GMT',
          );

        if (requests.length == 1) {
          request.response.write('''
#EXTM3U
#EXTINF:-1 group-title="News",Conditional News
https://cdn.example.com/conditional-news.m3u8
''');
        } else {
          request.response.statusCode = HttpStatus.notModified;
        }
        await request.response.close();
      });

      await parser.setPlaylistUrl(
        'http://${server.address.address}:${server.port}/playlist.m3u',
      );

      final initial = await parser.fetchPlaylist(forceRefresh: true);
      final refreshed = await parser.fetchPlaylist(forceRefresh: true);

      expect(initial, hasLength(1));
      expect(refreshed, hasLength(1));
      expect(refreshed.single.name, 'Conditional News');
      expect(
        refreshed.single.streamUrl,
        'https://cdn.example.com/conditional-news.m3u8',
      );
      expect(requests, hasLength(2));
      expect(
        requests.last.value(HttpHeaders.ifNoneMatchHeader),
        '"playlist-v1"',
      );
      expect(
        requests.last.value(HttpHeaders.ifModifiedSinceHeader),
        'Wed, 21 Oct 2015 07:28:00 GMT',
      );
      expect(
        requests.last.value(HttpHeaders.acceptEncodingHeader),
        contains('gzip'),
      );
    });

    test('drops oversized HTTP validators without failing import', () async {
      parser = M3UParserService(
        dio: Dio(),
        prefs: prefs,
        cacheDirectoryProvider: () async => cacheDir,
        maxPreferenceValueBytes: 96,
      );

      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));

      server.listen((request) async {
        request.response.headers
          ..set(HttpHeaders.etagHeader, '"${'validator' * 24}"')
          ..set(
            HttpHeaders.lastModifiedHeader,
            'Wed, 21 Oct 2015 07:28:00 GMT',
          );
        request.response.write('''
#EXTM3U
#EXTINF:-1 group-title="News",Oversized Validator News
https://cdn.example.com/oversized-validator-news.m3u8
''');
        await request.response.close();
      });

      await parser.setPlaylistUrl(
        'http://${server.address.address}:${server.port}/playlist.m3u',
      );

      final channels = await parser.fetchPlaylist(forceRefresh: true);

      expect(channels.single.name, 'Oversized Validator News');
      expect(prefs.getString('iptv_playlist_etag'), isNull);
      expect(
        prefs.getString('iptv_playlist_last_modified'),
        'Wed, 21 Oct 2015 07:28:00 GMT',
      );
    });
  });
}

class _RecordingWorkerExecutor implements AiroWorkerExecutor {
  var calls = 0;
  final debugNames = <String>[];
  final kinds = <AiroWorkerJobKind>[];

  @override
  bool get forceInline => true;

  @override
  Future<T> run<T>({
    required String debugName,
    required AiroWorkerJobKind kind,
    required AiroWorkerComputation<T> computation,
  }) async {
    calls++;
    debugNames.add(debugName);
    kinds.add(kind);
    return Future<T>.sync(computation);
  }
}
