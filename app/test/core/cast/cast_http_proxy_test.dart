import 'dart:convert';
import 'dart:io';

import 'package:airo_app/core/cast/cast_http_proxy.dart';
import 'package:flutter_test/flutter_test.dart';

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
          '#EXTM3U\n#EXT-X-KEY:METHOD=AES-128,URI="key.bin"\nsegment1.ts\n',
        );
        await request.response.close();
        return;
      }
      if (request.uri.path == '/segment1.ts') {
        // No CORS headers here on purpose — this is what a typical IPTV
        // origin sends, and what crashes playback on the Cast receiver.
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

  test(
    'rewrites playlist segment and key URIs to route through the proxy',
    () async {
      final originUrl = Uri.parse(
        'http://${origin.address.address}:${origin.port}/playlist.m3u8',
      );
      final proxiedUrl = proxy.proxiedUrl(originUrl);

      final client = HttpClient();
      final response = await (await client.getUrl(proxiedUrl)).close();
      final body = await response.transform(utf8.decoder).join();

      expect(response.headers.value('access-control-allow-origin'), '*');
      expect(
        body,
        contains('URI="${proxy.proxiedUrl(originUrl.resolve('key.bin'))}"'),
      );
      expect(
        body,
        contains(proxy.proxiedUrl(originUrl.resolve('segment1.ts')).toString()),
      );
      client.close(force: true);
    },
  );

  test(
    'proxies segment bytes and attaches CORS headers the origin omits',
    () async {
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

      expect(response.headers.value('access-control-allow-origin'), '*');
      expect(bytes, [1, 2, 3, 4]);
      client.close(force: true);
    },
  );
}
