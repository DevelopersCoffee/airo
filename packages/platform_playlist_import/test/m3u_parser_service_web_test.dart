import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_playlist_import/platform_playlist_import.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Regression coverage for the web platform target, which has no real
/// filesystem: `dart:io` File/Directory calls compile but throw
/// `UnsupportedError` at runtime there. `kIsWeb` is a compile-time constant,
/// so these tests inject `isWeb: true` to exercise that path on the VM test
/// runner (see [M3UParserService]'s `isWeb` constructor parameter).
void main() {
  group('M3UParserService web fetch path', () {
    late SharedPreferences prefs;
    late Directory workDir;
    late HttpServer server;
    late String base;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      workDir = await Directory.systemTemp.createTemp(
        'platform_playlist_import_web_test_',
      );
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        request.response.write('''
#EXTM3U
#EXTINF:-1 group-title="News",Web Fetched News
https://cdn.example.com/web-fetched-news.m3u8
''');
        await request.response.close();
      });
      base = 'http://${server.address.address}:${server.port}';
    });

    tearDown(() async {
      await server.close(force: true);
      if (workDir.existsSync()) {
        await workDir.delete(recursive: true);
      }
    });

    // Fetching to a temp file (dio.download → dart:io File/Directory) is
    // exactly what crashes on a real web build; asserting the download
    // directory is never created proves this path can't hit that crash.
    test('fetches and parses the playlist without touching the filesystem', () async {
      final parser = M3UParserService(
        dio: Dio(),
        prefs: prefs,
        isWeb: true,
        cacheDirectoryProvider: () async => workDir,
        downloadDirectoryProvider: () async => workDir,
      );
      await parser.setPlaylistUrl('$base/playlist.m3u');

      final channels = await parser.fetchPlaylist(forceRefresh: true);

      expect(channels, hasLength(1));
      expect(channels.single.name, 'Web Fetched News');
      final downloadDir = Directory('${workDir.path}/playlist_downloads');
      expect(
        downloadDir.existsSync(),
        isFalse,
        reason:
            'web fetch must stay in-memory; a download dir means it tried '
            'dart:io file download, which throws on a real web build',
      );
    });

    test('reports source unavailable on fetch failure, not a crash', () async {
      final parser = M3UParserService(
        dio: Dio(),
        prefs: prefs,
        isWeb: true,
        cacheDirectoryProvider: () async => workDir,
        downloadDirectoryProvider: () async => workDir,
      );
      await parser.setPlaylistUrl('$base/does-not-matter.m3u');
      await server.close(force: true);

      final outcome = await parser.fetchPlaylistOutcome(forceRefresh: true);

      expect(outcome.sourceUnavailable, isTrue);
      expect(outcome.channels, isEmpty);
    });

    test('staged import reaches ready without touching the filesystem', () async {
      final parser = M3UParserService(
        dio: Dio(),
        prefs: prefs,
        isWeb: true,
        cacheDirectoryProvider: () async => workDir,
        downloadDirectoryProvider: () async => workDir,
      );
      await parser.setPlaylistUrl('$base/playlist.m3u');

      final stages = await parser
          .fetchPlaylistWithProgress(forceRefresh: true)
          .map((progress) => progress.stage)
          .toList();

      expect(stages.last, ImportStage.ready);
      expect(stages, isNot(contains(ImportStage.failed)));
      final downloadDir = Directory('${workDir.path}/playlist_downloads');
      expect(downloadDir.existsSync(), isFalse);
    });
  });
}
