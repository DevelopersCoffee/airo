import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_playlist_import/platform_playlist_import.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Covers `M3UParserService.fetchPlaylistOutcome`, which exists so a caller can
/// tell an unreachable source from an empty one. `fetchPlaylist` returns an
/// empty list for both, and collapsing them made a dead playlist render as an
/// unconfigured one on the rig Pixel 9.
///
/// Uses the same real-`HttpServer` seam as this package's other tests rather
/// than a fake Dio adapter.
void main() {
  late SharedPreferences prefs;
  late Directory cacheDir;
  late M3UParserService parser;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    cacheDir = await Directory.systemTemp.createTemp(
      'm3u_parser_service_outcome_test_',
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

  test('an unreachable source reports sourceUnavailable', () async {
    // Bind and immediately release the port so the connection is refused.
    final probe = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final deadPort = probe.port;
    await probe.close(force: true);
    await parser.setPlaylistUrl(
      'http://${InternetAddress.loopbackIPv4.address}:$deadPort/playlist.m3u',
    );

    final outcome = await parser.fetchPlaylistOutcome();

    expect(outcome.sourceUnavailable, isTrue);
    expect(outcome.channels, isEmpty);
  });

  test('a source with no channels is empty, not unavailable', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      request.response.write('#EXTM3U\n');
      await request.response.close();
    });
    await parser.setPlaylistUrl(
      'http://${server.address.address}:${server.port}/playlist.m3u',
    );

    final outcome = await parser.fetchPlaylistOutcome();

    expect(outcome.channels, isEmpty);
    expect(
      outcome.sourceUnavailable,
      isFalse,
      reason: 'the source answered; it simply carried no channels',
    );
  });

  test('an unconfigured source is empty, not unavailable', () async {
    final outcome = await parser.fetchPlaylistOutcome();

    expect(outcome.channels, isEmpty);
    expect(outcome.sourceUnavailable, isFalse);
  });

  test('a reachable source loads channels and reports availability', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      request.response.write('''
#EXTM3U
#EXTINF:-1 group-title="News",Outcome News
https://cdn.example.com/outcome-news.m3u8
''');
      await request.response.close();
    });
    await parser.setPlaylistUrl(
      'http://${server.address.address}:${server.port}/playlist.m3u',
    );

    final outcome = await parser.fetchPlaylistOutcome();

    expect(outcome.sourceUnavailable, isFalse);
    expect(outcome.channels, hasLength(1));
    expect(outcome.channels.single.name, 'Outcome News');
  });

  test('fetchPlaylist keeps returning the outcome channels', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      request.response.write('''
#EXTM3U
#EXTINF:-1 group-title="News",Outcome News
https://cdn.example.com/outcome-news.m3u8
''');
      await request.response.close();
    });
    await parser.setPlaylistUrl(
      'http://${server.address.address}:${server.port}/playlist.m3u',
    );

    expect(await parser.fetchPlaylist(), hasLength(1));
  });
}
