import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_playlist/platform_playlist.dart';

import '../test_support/fake_http_client_adapter.dart';

void main() {
  // Dio's RequestOptions.path stores the literal string passed to
  // dio.get(...)/dio.post(...); JellyfinClient always passes a full
  // absolute URL (it never relies on Dio's baseUrl — same convention as
  // XtreamClient/StalkerClient), so the fake's handler keys below are full
  // URLs, not bare paths. See xtream_client_test.dart for the same fix.
  const authUrl = 'https://jellyfin.example.com/Users/AuthenticateByName';
  const channelsUrl = 'https://jellyfin.example.com/LiveTv/Channels';

  test(
    'authenticate() posts Username/Pw and returns AccessToken/User.Id',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://jellyfin.example.com'));
      dio.httpClientAdapter = FakeHttpClientAdapter({
        authUrl: (options) {
          expect(
            options.headers['X-Emby-Authorization'],
            contains('Client="Airo TV"'),
          );
          return Response(
            requestOptions: options,
            statusCode: 200,
            data: {
              'AccessToken': 'jf-token',
              'User': {'Id': 'user-1', 'Name': 'alice'},
            },
          );
        },
      });
      final client = JellyfinClient(
        dio: dio,
        serverUrl: 'https://jellyfin.example.com',
        username: 'alice',
        password: 'hunter2',
      );

      final result = await client.authenticate();

      expect(result.accessToken, 'jf-token');
      expect(result.userId, 'user-1');
    },
  );

  test('getLiveTvChannels() maps Id/Name/Number', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://jellyfin.example.com'));
    dio.httpClientAdapter = FakeHttpClientAdapter({
      channelsUrl: (options) => Response(
        requestOptions: options,
        statusCode: 200,
        data: {
          'Items': [
            {'Id': 'chan-1', 'Name': 'News', 'Number': '1'},
          ],
          'TotalRecordCount': 1,
        },
      ),
    });
    final client = JellyfinClient(
      dio: dio,
      serverUrl: 'https://jellyfin.example.com',
      username: 'alice',
      password: 'hunter2',
    );

    final channels = await client.getLiveTvChannels(
      accessToken: 'jf-token',
      userId: 'user-1',
    );

    expect(channels.single.id, 'chan-1');
    expect(channels.single.name, 'News');
    expect(channels.single.number, '1');
  });

  test(
    'getPrograms() parses StartDate/EndDate as UTC-aware instants',
    () async {
      const programsUrl = 'https://jellyfin.example.com/LiveTv/Programs';
      final dio = Dio(BaseOptions(baseUrl: 'https://jellyfin.example.com'));
      dio.httpClientAdapter = FakeHttpClientAdapter({
        programsUrl: (options) => Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            'Items': [
              {
                'Id': 'prog-1',
                'Name': 'Evening News',
                'ChannelId': 'chan-1',
                'StartDate': '2026-07-16T18:00:00.0000000Z',
                'EndDate': '2026-07-16T18:30:00.0000000Z',
                'Overview': 'Top stories',
              },
            ],
          },
        ),
      });
      final client = JellyfinClient(
        dio: dio,
        serverUrl: 'https://jellyfin.example.com',
        username: 'alice',
        password: 'hunter2',
      );

      final programs = await client.getPrograms(
        accessToken: 'jf-token',
        userId: 'user-1',
        channelIds: ['chan-1'],
      );

      expect(programs.single.id, 'prog-1');
      expect(programs.single.channelId, 'chan-1');
      expect(programs.single.startDate.isUtc, isTrue);
      expect(programs.single.endDate.isUtc, isTrue);
      expect(programs.single.startDate, DateTime.utc(2026, 7, 16, 18, 0, 0));
      expect(programs.single.endDate, DateTime.utc(2026, 7, 16, 18, 30, 0));
    },
  );

  test('streamUrl builds /Videos/{itemId}/stream with api_key', () {
    final client = JellyfinClient(
      dio: Dio(),
      serverUrl: 'https://jellyfin.example.com',
      username: 'alice',
      password: 'hunter2',
    );

    expect(
      client.streamUrl('chan-1', 'jf-token'),
      'https://jellyfin.example.com/Videos/chan-1/stream?api_key=jf-token&static=true',
    );
  });
}
