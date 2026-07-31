import 'dart:async';
import 'dart:io';

import 'package:airo_app/core/portability/airo_backup_service.dart';
import 'package:airo_app/core/portability/airo_lan_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'LAN share transfers only an encrypted envelope and closes cleanly',
    () async {
      final backup = await AiroBackupService().encrypt({
        'scope': 'airo-mind',
        'value': 'private',
      }, 'correct horse battery staple');
      final service = AiroLanSyncService();
      final share = await service.createShare(
        backup,
        advertisedHost: '127.0.0.1',
      );
      addTearDown(share.close);

      final fetched = await service.fetchShare(share.uri);
      expect(fetched, backup);
      expect(fetched, isNot(contains('private')));

      await share.close();
      await expectLater(service.fetchShare(share.uri), throwsA(anything));
    },
  );

  test('LAN share picks a routable host when none is supplied', () async {
    // Production never passes advertisedHost, so the interface lookup is the
    // path that actually ships. A share URI pointing at a loopback or wildcard
    // address is useless to the other device.
    final share = await AiroLanSyncService().createShare('encrypted-envelope');
    addTearDown(share.close);

    expect(share.uri.scheme, 'http');
    expect(share.uri.port, greaterThan(0));
    expect(share.uri.host, isNotEmpty);
    expect(
      share.uri.host,
      isNot('0.0.0.0'),
      reason: 'the bind wildcard is not an address a peer can reach',
    );
    expect(share.uri.path, startsWith('/airo-sync/'));
  });

  test('LAN share stops serving once its TTL elapses', () async {
    final service = AiroLanSyncService();
    final share = await service.createShare(
      'encrypted-envelope',
      ttl: const Duration(milliseconds: 50),
      advertisedHost: '127.0.0.1',
    );
    addTearDown(share.close);

    expect(await service.fetchShare(share.uri), 'encrypted-envelope');

    await Future<void>.delayed(const Duration(milliseconds: 200));

    await expectLater(
      service.fetchShare(share.uri),
      throwsA(anything),
      reason: 'an expired share must not keep serving the envelope',
    );
  });

  test('LAN share rejects unsupported schemes', () async {
    await expectLater(
      AiroLanSyncService().fetchShare(Uri.parse('ftp://example.test/x')),
      throwsA(isA<FormatException>()),
    );
  });

  test('LAN share serves the envelope only on the exact token route', () async {
    final backup = await AiroBackupService().encrypt({
      'scope': 'airo-mind',
      'value': 'private',
    }, 'correct horse battery staple');
    final service = AiroLanSyncService();
    final share = await service.createShare(
      backup,
      advertisedHost: '127.0.0.1',
    );
    addTearDown(share.close);

    // The token in the path is the only thing protecting the envelope, so a
    // near-miss must not serve it: no prefix match, no bare host, no parent
    // path. A guess that returned 200 would hand the backup to anyone on the
    // same network.
    final guesses = <Uri>[
      share.uri.replace(path: '/airo-sync/'),
      share.uri.replace(path: '/airo-sync'),
      share.uri.replace(path: '${share.uri.path}x'),
      share.uri.replace(path: '/'),
    ];

    for (final guess in guesses) {
      await expectLater(
        service.fetchShare(guess),
        throwsA(isA<FormatException>()),
        reason: '$guess must not resolve to the share',
      );
    }

    // The real route still works, so the rejections above are the token check
    // and not a dead server.
    expect(await service.fetchShare(share.uri), backup);
  });

  test('LAN share ignores non-GET requests on the token route', () async {
    final service = AiroLanSyncService();
    final share = await service.createShare(
      'encrypted-envelope',
      advertisedHost: '127.0.0.1',
    );
    addTearDown(share.close);

    final client = HttpClient();
    addTearDown(() => client.close(force: true));
    final request = await client.postUrl(share.uri);
    final response = await request.close();

    expect(
      response.statusCode,
      HttpStatus.notFound,
      reason: 'only GET reads a share; other verbs must not be routed',
    );
  });

  test('LAN share refuses to publish a backup past the payload cap', () async {
    final oversized = 'x' * (AiroLanSyncService.maxPayloadBytes + 1);

    await expectLater(
      AiroLanSyncService().createShare(oversized, advertisedHost: '127.0.0.1'),
      throwsA(isA<FormatException>()),
      reason: 'the cap has to reject before a server is bound',
    );
  });

  test('LAN share import rejects a non-OK response', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) {
      request.response
        ..statusCode = HttpStatus.forbidden
        ..close();
    });

    await expectLater(
      AiroLanSyncService().fetchShare(
        Uri.parse('http://127.0.0.1:${server.port}/airo-sync/token'),
      ),
      throwsA(isA<FormatException>()),
      reason: 'an error body must never be decoded as a backup envelope',
    );
  });

  test('LAN share import rejects an oversized declared body', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentLength = AiroLanSyncService.maxPayloadBytes + 1
        ..add(const [0x41]);
      // One byte is enough to get the headers delivered; the client only sees
      // Content-Length once body data starts flowing. The body then stays open
      // so the declared length -- not a short read or a closed socket -- is
      // what the service reacts to.
      await request.response.flush();
    });

    await expectLater(
      AiroLanSyncService().fetchShare(
        Uri.parse('http://127.0.0.1:${server.port}/airo-sync/token'),
      ),
      throwsA(isA<FormatException>()),
      reason: 'the declared length must be refused before buffering the body',
    );
  });

  test('LAN share import times out when the response stalls', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentLength = 1;
      await request.response.flush();
      // Leave the declared byte unread to model a stalled transfer.
    });

    final service = AiroLanSyncService(
      transferTimeout: const Duration(milliseconds: 50),
    );
    await expectLater(
      service.fetchShare(Uri.parse('http://127.0.0.1:${server.port}/stalled')),
      throwsA(isA<TimeoutException>()),
    );
  });
}
