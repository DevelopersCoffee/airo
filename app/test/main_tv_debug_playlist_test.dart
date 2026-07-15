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

    unawaited(
      server.forEach((request) {
        request.response
          ..headers.contentType = ContentType.text
          ..write('''
#EXTM3U
#EXTINF:-1 tvg-id="news.local" group-title="News",Airo News
https://example.test/live/news.m3u8
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
      );
      expect(seeded, isTrue);
      await warmTvDebugDefaultPlaylistCache(prefs, playlistUrl: playlistUrl);
    } finally {
      await server.close(force: true);
    }

    final parser = M3UParserService(dio: Dio(), prefs: prefs);
    expect(parser.getPlaylistUrl(), playlistUrl);

    final cachedChannels = await parser.fetchPlaylist();
    expect(cachedChannels, hasLength(1));
    expect(cachedChannels.single.name, 'Airo News');
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
  _RecordingM3UParserService(SharedPreferences prefs)
    : super(dio: Dio(), prefs: prefs);

  var fetchCalls = 0;

  @override
  Future<List<IPTVChannel>> fetchPlaylist({bool forceRefresh = false}) async {
    fetchCalls++;
    return const [];
  }
}
