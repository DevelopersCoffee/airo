import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:feature_iptv/application/airo_tv_bootstrap.dart';
import 'package:feature_iptv/application/mutable_xmltv_compact_epg_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_epg/platform_epg.dart';
import 'package:platform_playlist_import/platform_playlist_import.dart';
import 'package:platform_worker_jobs/platform_worker_jobs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'debug EPG warmup uses the shared worker-backed bootstrap helper',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.utc(2026, 7, 15, 9, 30);
      final server = await _xmltvServer('''
<tv>
  <programme channel="news.local" start="20260715090000 +0000" stop="20260715100000 +0000">
    <title>Morning Bulletin</title>
  </programme>
</tv>
''');
      final repository = SnapshotBackedCompactEpgRepository(
        store: InMemoryCompactEpgSnapshotStore(),
      );
      final windowRepository = MutableXmltvCompactEpgRepository();
      final downloadDir = await Directory.systemTemp.createTemp(
        'airo-tv-bootstrap-epg-',
      );
      addTearDown(() async {
        if (await downloadDir.exists()) {
          await downloadDir.delete(recursive: true);
        }
      });
      final parser = _RecordingM3UParserService(prefs, const [
        IPTVChannel(
          id: 'stream-news',
          name: 'Airo News',
          streamUrl: 'https://example.com/news.m3u8',
          tvgName: 'news.local',
        ),
      ]);

      try {
        final elapsed = await warmAiroTvDebugDefaultEpgCache(
          prefs,
          repository: repository,
          windowRepository: windowRepository,
          epgUrl: _serverUrl(server, '/guide.xml'),
          parser: parser,
          epgDownloadDirectoryProvider: () async => downloadDir,
          clock: () => now,
          workerExecutor: const AiroWorkerExecutor(forceInline: true),
        );

        expect(elapsed, isNotNull);
        expect(parser.fetchCalls, 1);
        final snapshot = await repository.loadCurrentNext(
          channelIds: const ['stream-news'],
          now: now,
        );
        expect(
          snapshot.entryForChannel('stream-news')?.current?.title,
          'Morning Bulletin',
        );
        final window = await windowRepository.loadWindow(
          GuideWindowQuery(
            channelIds: const ['stream-news'],
            windowStart: DateTime.utc(2026, 7, 15, 9),
            windowEnd: DateTime.utc(2026, 7, 15, 10),
            now: now,
          ),
        );
        expect(window.availabilityAt(now), CompactEpgAvailability.available);
        expect(await downloadDir.list().isEmpty, isTrue);
      } finally {
        await server.close(force: true);
      }
    },
  );
}

class _RecordingM3UParserService extends M3UParserService {
  _RecordingM3UParserService(
    SharedPreferences prefs, [
    this.channels = const [],
  ]) : super(dio: Dio(), prefs: prefs);

  final List<IPTVChannel> channels;
  var fetchCalls = 0;

  @override
  Future<List<IPTVChannel>> fetchPlaylist({bool forceRefresh = false}) async {
    fetchCalls++;
    return channels;
  }
}

Future<HttpServer> _xmltvServer(String body) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  unawaited(
    server.forEach((request) {
      request.response
        ..headers.contentType = ContentType.text
        ..write(body)
        ..close();
    }),
  );
  return server;
}

String _serverUrl(HttpServer server, String path) {
  return Uri(
    scheme: 'http',
    host: InternetAddress.loopbackIPv4.address,
    port: server.port,
    path: path,
  ).toString();
}
