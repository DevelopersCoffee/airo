import 'dart:convert';
import 'dart:io';

import 'package:feature_iptv/application/services/tv_playlist_pairing_server.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TvPlaylistPairingServer serverFor({
    String token = 'test-pairing-token',
    Duration idleTimeout = const Duration(minutes: 5),
    Duration stopGracePeriod = const Duration(milliseconds: 20),
  }) {
    return TvPlaylistPairingServer(
      bindAddress: InternetAddress.loopbackIPv4,
      token: token,
      idleTimeout: idleTimeout,
      stopGracePeriod: stopGracePeriod,
    );
  }

  Future<HttpClientResponse> request(
    Uri url, {
    String method = 'GET',
    String? body,
  }) async {
    final client = HttpClient();
    try {
      final httpRequest = await client.openUrl(method, url);
      if (body != null) {
        httpRequest.headers.contentType = ContentType(
          'application',
          'x-www-form-urlencoded',
        );
        httpRequest.write(body);
      }
      return await httpRequest.close();
    } finally {
      client.close(force: true);
    }
  }

  test('binds only to the loopback/private address given', () async {
    final server = serverFor();
    addTearDown(server.stop);
    final url = await server.start();

    expect(url.host, InternetAddress.loopbackIPv4.address);
    expect(url.path, '/pair/test-pairing-token');
  });

  test('GET on the token path serves the pairing form', () async {
    final server = serverFor();
    addTearDown(server.stop);
    final url = await server.start();

    final response = await request(url);
    final content = await response.transform(utf8.decoder).join();

    expect(response.statusCode, HttpStatus.ok);
    expect(content, contains('<form'));
  });

  test('unknown path is rejected with 404', () async {
    final server = serverFor();
    addTearDown(server.stop);
    final url = await server.start();

    final response = await request(url.replace(path: '/pair/wrong-token'));

    expect(response.statusCode, HttpStatus.notFound);
  });

  test('unsupported method is rejected with 405', () async {
    final server = serverFor();
    addTearDown(server.stop);
    final url = await server.start();

    final response = await request(url, method: 'PUT');

    expect(response.statusCode, HttpStatus.methodNotAllowed);
  });

  test('POST with a URL completes the result and consumes the token', () async {
    final server = serverFor();
    addTearDown(server.stop);
    final url = await server.start();

    final response = await request(
      url,
      method: 'POST',
      body:
          'url=${Uri.encodeQueryComponent('https://example.com/playlist.m3u')}',
    );

    expect(response.statusCode, HttpStatus.ok);
    expect(await server.result, 'https://example.com/playlist.m3u');
  });

  test('token is single-use: a second POST is rejected as gone', () async {
    final server = serverFor();
    addTearDown(server.stop);
    final url = await server.start();

    await request(
      url,
      method: 'POST',
      body: 'url=${Uri.encodeQueryComponent('https://example.com/a.m3u')}',
    );
    final second = await request(
      url,
      method: 'POST',
      body: 'url=${Uri.encodeQueryComponent('https://example.com/b.m3u')}',
    );

    expect(second.statusCode, HttpStatus.gone);
    // The first, legitimate submission is the one that wins -- a racing or
    // repeat POST can never overwrite an already-completed result.
    expect(await server.result, 'https://example.com/a.m3u');
  });

  test('POST with an empty URL re-shows the form and does not consume the '
      'token', () async {
    final server = serverFor();
    addTearDown(server.stop);
    final url = await server.start();

    final empty = await request(url, method: 'POST', body: 'url=');
    expect(empty.statusCode, HttpStatus.badRequest);

    final real = await request(
      url,
      method: 'POST',
      body: 'url=${Uri.encodeQueryComponent('https://example.com/c.m3u')}',
    );
    expect(real.statusCode, HttpStatus.ok);
    expect(await server.result, 'https://example.com/c.m3u');
  });

  test(
    'idle timeout resolves the result with null and stops the server',
    () async {
      final server = serverFor(idleTimeout: const Duration(milliseconds: 30));
      addTearDown(server.stop);
      await server.start();

      expect(await server.result, isNull);
      expect(server.isRunning, isFalse);
    },
  );

  test('cancel() resolves the result with null', () async {
    final server = serverFor();
    final url = await server.start();

    await server.cancel();

    expect(await server.result, isNull);
    expect(server.isRunning, isFalse);
    await expectLater(request(url), throwsA(isA<Object>()));
  });

  test('too many rejected requests stops the server', () async {
    final server = serverFor();
    addTearDown(server.stop);
    final url = await server.start();

    for (var i = 0; i < 25; i++) {
      try {
        await request(url.replace(path: '/pair/wrong'));
      } catch (_) {
        // The server may already be closing mid-loop; that's the point.
      }
    }

    expect(server.isRunning, isFalse);
  });

  test('toString never includes the submitted URL', () async {
    final server = serverFor();
    addTearDown(server.stop);
    final url = await server.start();

    await request(
      url,
      method: 'POST',
      body:
          'url=${Uri.encodeQueryComponent('https://secret.example/token=abc123')}',
    );
    await server.result;

    expect(server.toString(), isNot(contains('secret.example')));
    expect(server.toString(), isNot(contains('abc123')));
    expect(server.toString(), contains('redacted'));
  });
}
