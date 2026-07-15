import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:airo_app/core/cast/cast_http_proxy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late HttpServer origin;
  late CastHttpProxy proxy;

  // A 1 MB payload that simulates an HLS .ts segment for throughput tests.
  final bigPayload = Uint8List(1024 * 1024); // 1 MB of zeroes

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
      if (request.uri.path == '/big_segment.ts') {
        request.response.add(bigPayload);
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

  // -----------------------------------------------------------------------
  // Throughput benchmark (#771)
  //
  // Proxies a known 1 MB payload multiple times and measures aggregate
  // throughput. This is a smoke-test for the counting transformer and gives
  // a baseline MB/s number on CI machines. On developer laptops (loopback)
  // this typically reports >200 MB/s; on real Cast sessions the upstream
  // fetch is the bottleneck, not the local relay.
  // -----------------------------------------------------------------------
  test(
    'throughput benchmark: proxy 10 MB and verify byte counter',
    () async {
      final segmentUrl = Uri.parse(
        'http://${origin.address.address}:${origin.port}/big_segment.ts',
      );
      final proxied = proxy.proxiedUrl(segmentUrl);
      final client = HttpClient();

      const iterations = 10;
      final stopwatch = Stopwatch()..start();

      for (var i = 0; i < iterations; i++) {
        final response = await (await client.getUrl(proxied)).close();
        // Drain the body to ensure the proxy actually forwards all bytes.
        await response.drain<void>();
      }

      stopwatch.stop();
      final totalBytes = bigPayload.length * iterations;
      final seconds = stopwatch.elapsedMicroseconds / 1e6;
      final mbPerSec = totalBytes / (1024 * 1024) / seconds;

      // The proxy must have counted every forwarded byte.
      expect(proxy.totalBytesForwarded, totalBytes);

      // Sanity: even on slow CI, loopback throughput should exceed 1 MB/s.
      // On real hardware this is typically >200 MB/s.
      expect(mbPerSec, greaterThan(1.0));

      // Print for manual inspection in test output.
      // ignore: avoid_print
      print(
        '[CastProxy benchmark] ${(totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB '
        'in ${seconds.toStringAsFixed(3)}s = '
        '${mbPerSec.toStringAsFixed(1)} MB/s',
      );

      client.close(force: true);
    },
  );
}
