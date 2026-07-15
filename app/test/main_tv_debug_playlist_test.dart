import 'dart:async';
import 'dart:io';

import 'package:airo_app/core/platform/device_form_factor.dart';
import 'package:airo_app/main_tv.dart';
import 'package:dio/dio.dart';
import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('seeds DEBUG_IPTV_PLAYLIST_URL when no playlist exists', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final seeded = await seedTvDebugDefaultPlaylist(
      prefs,
      playlistUrl: 'https://example.com/tv.m3u',
    );

    final parser = M3UParserService(dio: Dio(), prefs: prefs);
    expect(seeded, isTrue);
    expect(parser.getPlaylistUrl(), 'https://example.com/tv.m3u');
  });

  test('does not overwrite an existing user playlist', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final parser = M3UParserService(dio: Dio(), prefs: prefs);
    await parser.setPlaylistUrl('https://example.com/user.m3u');

    final seeded = await seedTvDebugDefaultPlaylist(
      prefs,
      playlistUrl: 'https://example.com/debug.m3u',
    );

    expect(seeded, isFalse);
    expect(parser.getPlaylistUrl(), 'https://example.com/user.m3u');
  });

  test('does not fetch DEBUG_IPTV_PLAYLIST_URL during seed', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final parser = _RecordingM3UParserService(prefs);

    final seeded = await seedTvDebugDefaultPlaylist(
      prefs,
      playlistUrl: 'https://example.com/debug.m3u',
      parser: parser,
    );

    expect(seeded, isTrue);
    expect(parser.fetchCalls, 0);
    expect(parser.getPlaylistUrl(), 'https://example.com/debug.m3u');
  });

  test('warms cache for DEBUG_IPTV_PLAYLIST_URL fixture after seed', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final cacheDir = await Directory.systemTemp.createTemp(
      'airo_tv_playlist_cache_test_',
    );
    addTearDown(() async {
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
      }
    });
    final parser = M3UParserService(
      dio: Dio(),
      prefs: prefs,
      cacheDirectoryProvider: () async => cacheDir,
    );

    unawaited(
      server.forEach((request) {
        request.response
          ..headers.contentType = ContentType.text
          ..write('''
#EXTM3U
#EXTINF:-1 tvg-id="news.local" group-title="News",Airo News
https://cdn.example.com/live/news.m3u8
''')
          ..close();
      }),
    );

    final playlistUrl = Uri(
      scheme: 'http',
      host: InternetAddress.loopbackIPv4.address,
      port: server.port,
      path: '/fixture.m3u',
    ).toString();

    try {
      final seeded = await seedTvDebugDefaultPlaylist(
        prefs,
        playlistUrl: playlistUrl,
        parser: parser,
      );
      expect(seeded, isTrue);
      await warmTvDebugDefaultPlaylistCache(
        prefs,
        playlistUrl: playlistUrl,
        parser: parser,
      );

      expect(parser.getPlaylistUrl(), playlistUrl);

      final cachedChannels = await parser.fetchPlaylist();
      expect(cachedChannels, hasLength(1));
      expect(cachedChannels.single.name, 'Airo News');
    } finally {
      await server.close(force: true);
    }
  });

  test(
    'creates file-backed compact EPG repository for TV support dir',
    () async {
      final supportDir = await Directory.systemTemp.createTemp(
        'airo_tv_epg_support_',
      );
      addTearDown(() async {
        if (await supportDir.exists()) {
          await supportDir.delete(recursive: true);
        }
      });
      final repository = createTvCompactEpgRepository(
        supportDirectoryProvider: () async => supportDir,
      );
      final now = DateTime.utc(2026, 7, 15, 9, 30);

      await repository.saveSnapshot(
        CompactEpgSlice(
          entries: [
            CompactEpgEntry(
              channelId: 'news-1',
              channelName: 'Airo News',
              current: CompactEpgProgram(
                programId: 'news-current',
                title: 'Morning Bulletin',
                startsAt: now.subtract(const Duration(minutes: 10)),
                endsAt: now.add(const Duration(minutes: 20)),
              ),
            ),
          ],
          generatedAt: now,
          expiresAt: now.add(const Duration(minutes: 15)),
          source: CompactEpgSliceSource.localCache,
        ),
      );

      final result = await repository.loadCurrentNext(
        channelIds: const ['news-1'],
        now: now,
      );

      expect(
        File('${supportDir.path}/epg/compact_epg_snapshot.json').existsSync(),
        isTrue,
      );
      expect(
        result.entryForChannel('news-1')?.current?.title,
        'Morning Bulletin',
      );
    },
  );

  test('warms compact EPG snapshot from XMLTV using channel aliases', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.utc(2026, 7, 15, 9, 30);
    final server = await _xmltvServer('''
<tv>
  <programme channel="news.local" start="20260715090000 +0000" stop="20260715100000 +0000">
    <title>Morning Bulletin</title>
  </programme>
  <programme channel="42" start="20260715093000 +0000" stop="20260715103000 +0000">
    <title>Live Sports</title>
  </programme>
</tv>
''');
    final repository = SnapshotBackedCompactEpgRepository(
      store: InMemoryCompactEpgSnapshotStore(),
    );
    final downloadDir = await Directory.systemTemp.createTemp(
      'airo-tv-epg-download-',
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
      IPTVChannel(
        id: 'stream-sports',
        name: 'Airo Sports',
        streamUrl: 'https://example.com/sports.m3u8',
        tvgId: 42,
      ),
    ]);

    try {
      final elapsed = await warmTvDebugDefaultEpgCache(
        prefs,
        repository: repository,
        epgUrl: _serverUrl(server, '/guide.xml'),
        parser: parser,
        epgDownloadDirectoryProvider: () async => downloadDir,
        clock: () => now,
      );

      final snapshot = await repository.loadCurrentNext(
        channelIds: const ['stream-news', 'stream-sports'],
        now: now,
      );

      expect(elapsed, isNotNull);
      expect(elapsed!, lessThan(const Duration(seconds: 1)));
      expect(
        snapshot.entryForChannel('stream-news')?.current?.title,
        'Morning Bulletin',
      );
      expect(
        snapshot.entryForChannel('stream-sports')?.current?.title,
        'Live Sports',
      );
      expect(snapshot.entryForChannel('news.local'), isNull);
      expect(await downloadDir.list().isEmpty, isTrue);
    } finally {
      await server.close(force: true);
    }
  });

  test('schedules DEBUG_IPTV_EPG_URL warmup after frame', () async {
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
    final downloadDir = await Directory.systemTemp.createTemp(
      'airo-tv-epg-deferred-download-',
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
    final logs = <String>[];
    void Function(Duration timestamp)? frameCallback;

    scheduleTvDebugDefaultEpgWarmup(
      prefs,
      repository: repository,
      epgUrl: _serverUrl(server, '/guide.xml'),
      parser: parser,
      epgDownloadDirectoryProvider: () async => downloadDir,
      clock: () => now,
      addPostFrameCallback: (callback) {
        frameCallback = callback;
      },
      log: logs.add,
    );

    expect(parser.fetchCalls, 0);

    try {
      frameCallback!(Duration.zero);
      for (var attempt = 0; attempt < 20; attempt++) {
        if (logs.contains(
          '✅ Deferred startup task completed: tv_debug_epg_warmup',
        )) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      expect(parser.fetchCalls, 1);
      expect(
        logs,
        contains('✅ Deferred startup task completed: tv_debug_epg_warmup'),
      );
      expect(
        (await repository.loadCurrentNext(
          channelIds: const ['stream-news'],
          now: now,
        )).entryForChannel('stream-news')?.current?.title,
        'Morning Bulletin',
      );
    } finally {
      await server.close(force: true);
    }
  });

  test('schedules DEBUG_IPTV_PLAYLIST_URL warmup after frame', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final parser = _RecordingM3UParserService(prefs);
    final logs = <String>[];
    void Function(Duration timestamp)? frameCallback;
    const playlistUrl = 'https://example.com/deferred.m3u';

    await seedTvDebugDefaultPlaylist(
      prefs,
      playlistUrl: playlistUrl,
      parser: parser,
    );

    scheduleTvDebugDefaultPlaylistWarmup(
      prefs,
      playlistUrl: playlistUrl,
      parser: parser,
      addPostFrameCallback: (callback) {
        frameCallback = callback;
      },
      log: logs.add,
    );

    expect(parser.fetchCalls, 0);

    frameCallback!(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(parser.fetchCalls, 1);
    expect(
      logs,
      contains('✅ Deferred startup task completed: tv_debug_playlist_warmup'),
    );
  });

  test('initializes TV Firebase through deferred startup task', () async {
    isFirebaseInitialized = false;
    var initialized = false;
    final logs = <String>[];
    void Function(Duration timestamp)? frameCallback;

    scheduleTvFirebaseInitialization(
      isConfigured: true,
      variantName: 'tvTest',
      initializeApp: () async {
        initialized = true;
      },
      addPostFrameCallback: (callback) {
        frameCallback = callback;
      },
      log: logs.add,
    );

    expect(initialized, isFalse);
    expect(isFirebaseInitialized, isFalse);

    frameCallback!(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(initialized, isTrue);
    expect(isFirebaseInitialized, isTrue);
    expect(logs, contains('✅ Firebase initialized (TV variant: tvTest)'));
    expect(
      logs,
      contains('✅ Deferred startup task completed: tv_firebase_initialization'),
    );
  });

  test('skips TV Firebase when platform options are not configured', () async {
    isFirebaseInitialized = true;
    final logs = <String>[];

    final initialized = await initializeTvFirebase(
      isConfigured: false,
      log: logs.add,
    );

    expect(initialized, isFalse);
    expect(isFirebaseInitialized, isFalse);
    expect(
      logs,
      contains('⚠️ Firebase not configured for this platform; skipping init'),
    );
  });

  test('does not lock orientation on mobile devices', () async {
    List<DeviceOrientation>? orientations;
    SystemUiMode? systemUiMode;

    await configureTvSystemChrome(
      detectFormFactor: () async => DeviceFormFactor.mobile,
      setPreferredOrientations: (value) async {
        orientations = value;
      },
      setEnabledSystemUIMode: (mode, {overlays}) async {
        systemUiMode = mode;
      },
    );

    expect(orientations, isEmpty);
    expect(systemUiMode, SystemUiMode.edgeToEdge);
  });

  test('locks landscape only on TV devices', () async {
    List<DeviceOrientation>? orientations;
    SystemUiMode? systemUiMode;
    List<SystemUiOverlay>? systemUiOverlays;

    await configureTvSystemChrome(
      detectFormFactor: () async => DeviceFormFactor.tv,
      setPreferredOrientations: (value) async {
        orientations = value;
      },
      setEnabledSystemUIMode: (mode, {overlays}) async {
        systemUiMode = mode;
        systemUiOverlays = overlays;
      },
    );

    expect(orientations, [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    expect(systemUiMode, SystemUiMode.immersiveSticky);
    expect(systemUiOverlays, isEmpty);
  });
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
