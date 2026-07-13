import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:platform_player/src/services/cast_http_proxy.dart';

void main() {
  late HttpServer origin;
  late CastHttpProxy proxy;

  setUp(() async {
    origin = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    origin.listen((request) async {
      if (request.uri.path == '/playlist.m3u8') {
        request.response.headers.contentType = ContentType(
          'application',
          'vnd.apple.mpegurl',
        );
        request.response.write(
          '#EXTM3U\n'
          '#EXT-X-KEY:METHOD=AES-128,URI="key.bin"\n'
          '#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio",URI="audio.m3u8"\n'
          '#EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID="subs",URI="subs.m3u8"\n'
          '#EXT-X-MEDIA:TYPE=CLOSED-CAPTIONS,GROUP-ID="cc",INSTREAM-ID="CC1"\n'
          'segment1.ts\n',
        );
        await request.response.close();
        return;
      }
      if (request.uri.path == '/segment1.ts') {
        request.response.add([1, 2, 3, 4]);
        await request.response.close();
        return;
      }
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
    });

    proxy = CastHttpProxy();
    await proxy.start();
  });

  tearDown(() async {
    await proxy.stop();
    await origin.close(force: true);
  });

  test('rewrites playlist segment and key URIs through proxy', () async {
    final originUrl = Uri.parse(
      'http://${origin.address.address}:${origin.port}/playlist.m3u8',
    );
    final proxiedUrl = proxy.proxiedUrl(originUrl);

    final client = HttpClient();
    final response = await (await client.getUrl(proxiedUrl)).close();
    final body = await response.transform(utf8.decoder).join();
    client.close(force: true);

    expect(response.headers.value('access-control-allow-origin'), '*');
    expect(
      body,
      contains('URI="${proxy.proxiedUrl(originUrl.resolve('key.bin'))}"'),
    );
    expect(
      body,
      contains('URI="${proxy.proxiedUrl(originUrl.resolve('audio.m3u8'))}"'),
    );
    expect(body, isNot(contains('TYPE=SUBTITLES')));
    expect(body, isNot(contains('TYPE=CLOSED-CAPTIONS')));
    expect(
      body,
      contains(proxy.proxiedUrl(originUrl.resolve('segment1.ts')).toString()),
    );
  });

  test('proxies segment bytes and attaches CORS headers', () async {
    final originUrl = Uri.parse(
      'http://${origin.address.address}:${origin.port}/segment1.ts',
    );
    final proxiedUrl = proxy.proxiedUrl(originUrl);

    final client = HttpClient();
    final response = await (await client.getUrl(proxiedUrl)).close();
    final bytes = await response.fold<List<int>>(
      [],
      (acc, chunk) => acc..addAll(chunk),
    );
    client.close(force: true);

    expect(response.headers.value('access-control-allow-origin'), '*');
    expect(bytes, [1, 2, 3, 4]);
  });
}
