import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_playlist/platform_playlist.dart';

import '../test_support/fake_http_client_adapter.dart';

void main() {
  late Dio dio;

  // Dio's RequestOptions.path stores the literal string passed to
  // dio.get(...); XtreamClient always passes a full absolute URL (it never
  // relies on Dio's baseUrl — same convention as M3UParserService), so the
  // fake's handler keys below are full URLs, not bare paths.
  const playerApiUrl = 'https://xtream.example.com/player_api.php';

  test('authenticate() parses user_info/server_info', () async {
    dio = Dio(BaseOptions(baseUrl: 'https://xtream.example.com'));
    dio.httpClientAdapter = FakeHttpClientAdapter({
      playerApiUrl: (options) => Response(
        requestOptions: options,
        statusCode: 200,
        data: {
          'user_info': {'auth': 1, 'status': 'Active', 'max_connections': '1'},
          'server_info': {'url': 'xtream.example.com', 'https_port': '443'},
        },
      ),
    });
    final client = XtreamClient(
      dio: dio,
      serverUrl: 'https://xtream.example.com',
      username: 'user1',
      password: 'pass1',
    );

    final result = await client.authenticate();

    expect(result.isAuthenticated, isTrue);
    expect(result.status, 'Active');
  });

  test(
    'getLiveStreams() maps stream_id/name/stream_icon/category_id',
    () async {
      dio = Dio(BaseOptions(baseUrl: 'https://xtream.example.com'));
      dio.httpClientAdapter = FakeHttpClientAdapter({
        playerApiUrl: (options) => Response(
          requestOptions: options,
          statusCode: 200,
          data: [
            {
              'stream_id': 101,
              'name': 'News HD',
              'stream_icon': 'https://xtream.example.com/logo.png',
              'category_id': '5',
              'epg_channel_id': 'news.hd',
            },
          ],
        ),
      });
      final client = XtreamClient(
        dio: dio,
        serverUrl: 'https://xtream.example.com',
        username: 'user1',
        password: 'pass1',
      );

      final streams = await client.getLiveStreams();

      expect(streams, hasLength(1));
      expect(streams.single.streamId, 101);
      expect(streams.single.name, 'News HD');
      expect(streams.single.epgChannelId, 'news.hd');
    },
  );

  test('getShortEpg() base64-decodes title/description', () async {
    dio = Dio(BaseOptions(baseUrl: 'https://xtream.example.com'));
    dio.httpClientAdapter = FakeHttpClientAdapter({
      playerApiUrl: (options) => Response(
        requestOptions: options,
        statusCode: 200,
        data: {
          'epg_listings': [
            {
              'id': '1',
              'title': base64Encode(utf8.encode('Evening News')),
              'description': base64Encode(utf8.encode('Top stories')),
              'start': '2026-07-16 18:00:00',
              'end': '2026-07-16 18:30:00',
              'stream_id': '101',
            },
          ],
        },
      ),
    });
    final client = XtreamClient(
      dio: dio,
      serverUrl: 'https://xtream.example.com',
      username: 'user1',
      password: 'pass1',
    );

    final listings = await client.getShortEpg(streamId: 101);

    expect(listings.single.title, 'Evening News');
    expect(listings.single.description, 'Top stories');
  });

  test('getShortEpg() parses timestamps as UTC, not device-local', () async {
    dio = Dio(BaseOptions(baseUrl: 'https://xtream.example.com'));
    dio.httpClientAdapter = FakeHttpClientAdapter({
      playerApiUrl: (options) => Response(
        requestOptions: options,
        statusCode: 200,
        data: {
          'epg_listings': [
            {
              'id': '1',
              'title': base64Encode(utf8.encode('Test')),
              'description': base64Encode(utf8.encode('Test')),
              'start': '2026-07-16 18:00:00',
              'end': '2026-07-16 18:30:00',
              'stream_id': '101',
            },
          ],
        },
      ),
    });
    final client = XtreamClient(
      dio: dio,
      serverUrl: 'https://xtream.example.com',
      username: 'user1',
      password: 'pass1',
    );

    final listings = await client.getShortEpg(streamId: 101);

    expect(listings.single.start.isUtc, isTrue);
    expect(listings.single.end.isUtc, isTrue);
    expect(listings.single.start, DateTime.utc(2026, 7, 16, 18, 0, 0));
    expect(listings.single.end, DateTime.utc(2026, 7, 16, 18, 30, 0));
  });

  test(
    'authenticate() throws DioException when the server returns 401',
    () async {
      dio = Dio(BaseOptions(baseUrl: 'https://xtream.example.com'));
      dio.httpClientAdapter = FakeHttpClientAdapter({
        playerApiUrl: (options) => Response(
          requestOptions: options,
          statusCode: 401,
          data: {
            'user_info': {'auth': 0, 'status': 'Disabled'},
          },
        ),
      });
      final client = XtreamClient(
        dio: dio,
        serverUrl: 'https://xtream.example.com',
        username: 'user1',
        password: 'pass1',
      );

      await expectLater(client.authenticate(), throwsA(isA<DioException>()));
    },
  );

  group('health tracking (CV-012 slice-2)', () {
    test('successful authenticate() records fetchSuccess sample', () async {
      dio = Dio();
      dio.httpClientAdapter = FakeHttpClientAdapter({
        playerApiUrl: (options) => Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            'user_info': {'auth': 1, 'status': 'Active'},
          },
        ),
      });
      final tracker = ProviderHealthTracker();
      final client = XtreamClient(
        dio: dio,
        serverUrl: 'https://xtream.example.com',
        username: 'user1',
        password: 'pass1',
        healthTracker: tracker,
        sourceId: 'xtream-1',
      );

      await client.authenticate();

      final snap = tracker.snapshotFor('xtream-1');
      expect(snap.totalSamples, 1);
      expect(snap.healthClass, ProviderHealthClass.green);
    });

    test(
      '401 on authenticate() records fetchFailure(auth) and rethrows',
      () async {
        dio = Dio();
        dio.httpClientAdapter = FakeHttpClientAdapter({
          playerApiUrl: (options) => Response(
            requestOptions: options,
            statusCode: 401,
            data: {'error': 'unauthorized'},
          ),
        });
        final tracker = ProviderHealthTracker();
        final client = XtreamClient(
          dio: dio,
          serverUrl: 'https://xtream.example.com',
          username: 'user1',
          password: 'pass1',
          healthTracker: tracker,
          sourceId: 'xtream-1',
        );

        await expectLater(client.authenticate(), throwsA(isA<DioException>()));

        final snap = tracker.snapshotFor('xtream-1');
        expect(snap.recentFailureCategory, ProviderHealthFailureCategory.auth);
        expect(snap.failureRate, 1.0);
      },
    );

    test('no tracker → no recording, existing behavior preserved', () async {
      dio = Dio();
      dio.httpClientAdapter = FakeHttpClientAdapter({
        playerApiUrl: (options) => Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            'user_info': {'auth': 1, 'status': 'Active'},
          },
        ),
      });
      final client = XtreamClient(
        dio: dio,
        serverUrl: 'https://xtream.example.com',
        username: 'user1',
        password: 'pass1',
      );

      final result = await client.authenticate();
      expect(result.isAuthenticated, isTrue);
    });
  });

  test('liveStreamUrl builds username/password/stream_id path', () {
    final client = XtreamClient(
      dio: Dio(),
      serverUrl: 'https://xtream.example.com',
      username: 'user1',
      password: 'pass1',
    );

    expect(
      client.liveStreamUrl(101),
      'https://xtream.example.com/live/user1/pass1/101.m3u8',
    );
  });
}
