import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_playlist/platform_playlist.dart';

import '../test_support/fake_http_client_adapter.dart';

void main() {
  // Dio's RequestOptions.path stores the literal string passed to
  // dio.get(...); StalkerClient always passes a full absolute URL (it never
  // relies on Dio's baseUrl), so the fake's handler keys below are full
  // URLs, not bare paths. See xtream_client_test.dart for the same fix.
  const portalUrl = 'https://stalker.example.com/portal.php';

  test('handshake() sends mac cookie and returns token', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://stalker.example.com'));
    dio.httpClientAdapter = FakeHttpClientAdapter({
      portalUrl: (options) {
        expect(options.headers['Cookie'], contains('mac=AA:BB:CC:DD:EE:FF'));
        return Response(
          requestOptions: options,
          statusCode: 200,
          data: {'js': {'token': 'tok-123'}},
        );
      },
    });
    final client = StalkerClient(
      dio: dio,
      serverUrl: 'https://stalker.example.com',
      macAddress: 'AA:BB:CC:DD:EE:FF',
    );

    final token = await client.handshake();

    expect(token, 'tok-123');
  });

  test('handshake() throws DioException when the server returns 401', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://stalker.example.com'));
    dio.httpClientAdapter = FakeHttpClientAdapter({
      portalUrl: (options) => Response(
        requestOptions: options,
        statusCode: 401,
        data: {'js': null},
      ),
    });
    final client = StalkerClient(
      dio: dio,
      serverUrl: 'https://stalker.example.com',
      macAddress: 'AA:BB:CC:DD:EE:FF',
    );

    await expectLater(client.handshake(), throwsA(isA<DioException>()));
  });

  test('getChannels() maps id/name/number/logo/cmd', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://stalker.example.com'));
    dio.httpClientAdapter = FakeHttpClientAdapter({
      portalUrl: (options) => Response(
        requestOptions: options,
        statusCode: 200,
        data: {
          'js': {
            'data': [
              {
                'id': '1',
                'name': 'Sports 1',
                'number': '101',
                'logo': 'https://stalker.example.com/logo1.png',
                'cmd': 'ffmpeg http://localhost/ch/1_',
              },
            ],
          },
        },
      ),
    });
    final client = StalkerClient(
      dio: dio,
      serverUrl: 'https://stalker.example.com',
      macAddress: 'AA:BB:CC:DD:EE:FF',
    );

    final channels = await client.getChannels(token: 'tok-123');

    expect(channels.single.id, '1');
    expect(channels.single.name, 'Sports 1');
    expect(channels.single.number, '101');
    expect(channels.single.logo, 'https://stalker.example.com/logo1.png');
    expect(channels.single.cmd, 'ffmpeg http://localhost/ch/1_');
  });

  test('createLink() resolves cmd into a playable URL', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://stalker.example.com'));
    dio.httpClientAdapter = FakeHttpClientAdapter({
      portalUrl: (options) => Response(
        requestOptions: options,
        statusCode: 200,
        data: {'js': {'cmd': 'https://stalker.example.com/stream/1.m3u8'}},
      ),
    });
    final client = StalkerClient(
      dio: dio,
      serverUrl: 'https://stalker.example.com',
      macAddress: 'AA:BB:CC:DD:EE:FF',
    );

    final url = await client.createLink(
      token: 'tok-123',
      cmd: 'ffmpeg http://localhost/ch/1_',
    );

    expect(url, 'https://stalker.example.com/stream/1.m3u8');
  });
}
