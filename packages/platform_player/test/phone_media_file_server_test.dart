import 'dart:io';

import 'package:core_media_routing/core_media_routing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_player/platform_player.dart';

void main() {
  late Directory tempDir;
  late File mediaFile;
  late List<int> mediaBytes;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('phone_media_server_test');
    mediaBytes = List<int>.generate(4096, (i) => i % 251);
    mediaFile = File('${tempDir.path}/movie.mp4');
    await mediaFile.writeAsBytes(mediaBytes);
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  AiroTemporaryMobileServerSnapshot snapshotFor({
    DateTime? expiresAt,
    Duration idleTimeout = const Duration(minutes: 2),
  }) {
    final now = DateTime.now();
    return AiroTemporaryMobileServerSnapshot(
      serverId: 'server-1',
      hostNodeId: 'phone-node',
      locationId: 'loc-1',
      mediaId: 'media-1',
      accessGrant: AiroRouteAccessGrant(
        grantId: 'grant-1',
        locationId: 'loc-1',
        audienceNodeId: 'tv-node',
        handle: AiroRouteAccessHandle.redacted('grant-handle-1'),
        issuedAt: now,
        expiresAt: expiresAt ?? now.add(const Duration(hours: 2)),
        scopes: const {
          AiroRouteAccessScope.playbackRead,
          AiroRouteAccessScope.rangeRead,
          AiroRouteAccessScope.probeRead,
        },
      ),
      startedAt: now,
      expiresAt: expiresAt ?? now.add(const Duration(hours: 2)),
      batteryPercent: 80,
      thermalState: AiroTemporaryMobileThermalState.normal,
      allowedReceiverNodeIds: const {'tv-node'},
      capabilities: const {
        AiroTemporaryMobileServerCapability.lanOnly,
        AiroTemporaryMobileServerCapability.rangeRequests,
        AiroTemporaryMobileServerCapability.probeRequests,
        AiroTemporaryMobileServerCapability.entityValidation,
        AiroTemporaryMobileServerCapability.autoShutdownOnExpiry,
        AiroTemporaryMobileServerCapability.idleShutdown,
      },
      idleTimeout: idleTimeout,
    );
  }

  PhoneMediaFileServer serverFor({
    DateTime? expiresAt,
    Duration idleTimeout = const Duration(minutes: 2),
    String sessionToken = 'test-session-token',
  }) {
    return PhoneMediaFileServer(
      snapshot: snapshotFor(expiresAt: expiresAt, idleTimeout: idleTimeout),
      filePath: mediaFile.path,
      contentType: 'video/mp4',
      bindAddress: InternetAddress.loopbackIPv4,
      sessionToken: sessionToken,
    );
  }

  Future<HttpClientResponse> request(
    Uri url, {
    String method = 'GET',
    String? range,
  }) async {
    final client = HttpClient();
    final req = await client.openUrl(method, url);
    if (range != null) {
      req.headers.set(HttpHeaders.rangeHeader, range);
    }
    return req.close();
  }

  test('start binds a random port and returns a tokenized media url', () async {
    final server = serverFor();
    final url = await server.start();
    addTearDown(server.stopServer);

    expect(url.scheme, 'http');
    expect(url.port, isNot(0));
    expect(url.path, '/m/test-session-token/media');
  });

  test(
    'serves the full entity as 206 bytes=0- when no range is requested',
    () async {
      // The temporary-mobile-server contract is range-first: rangeless GETs are
      // served as a synthesized full-entity range so thin receivers still play.
      final server = serverFor();
      final url = await server.start();
      addTearDown(server.stopServer);

      final response = await request(url);
      expect(response.statusCode, HttpStatus.partialContent);
      expect(
        response.headers.value(HttpHeaders.contentRangeHeader),
        'bytes 0-4095/4096',
      );
      expect(response.headers.value(HttpHeaders.acceptRangesHeader), 'bytes');
      expect(response.headers.contentType?.mimeType, 'video/mp4');
      final body = await response.fold<List<int>>([], (a, b) => a..addAll(b));
      expect(body, mediaBytes);
    },
  );

  test('serves 206 partial content with correct Content-Range for a bounded '
      'range', () async {
    final server = serverFor();
    final url = await server.start();
    addTearDown(server.stopServer);

    final response = await request(url, range: 'bytes=100-199');
    expect(response.statusCode, HttpStatus.partialContent);
    expect(
      response.headers.value(HttpHeaders.contentRangeHeader),
      'bytes 100-199/4096',
    );
    final body = await response.fold<List<int>>([], (a, b) => a..addAll(b));
    expect(body, mediaBytes.sublist(100, 200));
  });

  test('serves suffix ranges so receivers can seek near the end', () async {
    final server = serverFor();
    final url = await server.start();
    addTearDown(server.stopServer);

    final response = await request(url, range: 'bytes=-100');
    expect(response.statusCode, HttpStatus.partialContent);
    expect(
      response.headers.value(HttpHeaders.contentRangeHeader),
      'bytes 3996-4095/4096',
    );
    final body = await response.fold<List<int>>([], (a, b) => a..addAll(b));
    expect(body, mediaBytes.sublist(3996));
  });

  test('rejects unsatisfiable ranges with 416', () async {
    final server = serverFor();
    final url = await server.start();
    addTearDown(server.stopServer);

    final response = await request(url, range: 'bytes=5000-6000');
    expect(response.statusCode, HttpStatus.requestedRangeNotSatisfiable);
  });

  test('answers HEAD probes with headers and no body', () async {
    final server = serverFor();
    final url = await server.start();
    addTearDown(server.stopServer);

    final response = await request(url, method: 'HEAD');
    expect(response.statusCode, HttpStatus.ok);
    expect(response.headers.value(HttpHeaders.acceptRangesHeader), 'bytes');
    expect(response.headers.value(HttpHeaders.etagHeader), isNotNull);
    final body = await response.fold<List<int>>([], (a, b) => a..addAll(b));
    expect(body, isEmpty);
  });

  test('returns 404 for requests without the session token', () async {
    final server = serverFor();
    final url = await server.start();
    addTearDown(server.stopServer);

    final bad = url.replace(path: '/m/wrong-token/media');
    final response = await request(bad, range: 'bytes=0-1');
    expect(response.statusCode, HttpStatus.notFound);

    final noToken = url.replace(path: '/media');
    final response2 = await request(noToken, range: 'bytes=0-1');
    expect(response2.statusCode, HttpStatus.notFound);
  });

  test('rejects non-GET/HEAD methods with 405', () async {
    final server = serverFor();
    final url = await server.start();
    addTearDown(server.stopServer);

    final response = await request(url, method: 'POST');
    expect(response.statusCode, HttpStatus.methodNotAllowed);
  });

  test('rejects requests once the session is expired', () async {
    final server = serverFor(
      expiresAt: DateTime.now().add(const Duration(milliseconds: 50)),
    );
    final url = await server.start();
    addTearDown(server.stopServer);

    await Future<void>.delayed(const Duration(milliseconds: 120));
    try {
      final response = await request(url, range: 'bytes=0-1');
      expect(response.statusCode, HttpStatus.forbidden);
    } on SocketException {
      // Auto-shutdown already closed the socket, which is equally valid.
    } on HttpException {
      // Connection torn down mid-request by auto-shutdown.
    }
  });

  test('stopServer closes the socket so new connections fail', () async {
    final server = serverFor();
    final url = await server.start();

    await server.stopServer();
    expect(server.isRunning, isFalse);
    await expectLater(request(url, range: 'bytes=0-1'), throwsA(anything));
  });

  test('idle sessions shut the server down automatically', () async {
    final server = serverFor(idleTimeout: const Duration(milliseconds: 100));
    await server.start();
    addTearDown(server.stopServer);

    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(server.isRunning, isFalse);
  });

  test('expired sessions shut the server down automatically', () async {
    final server = serverFor(
      expiresAt: DateTime.now().add(const Duration(milliseconds: 100)),
      idleTimeout: const Duration(minutes: 2),
    );
    await server.start();
    addTearDown(server.stopServer);

    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(server.isRunning, isFalse);
  });

  test('keepAlive prevents idle shutdown when the receiver is paused (no HTTP '
      'traffic) rather than disconnected', () async {
    final server = serverFor(idleTimeout: const Duration(milliseconds: 150));
    await server.start();
    addTearDown(server.stopServer);

    // Simulate a paused receiver: no requests land, but the handoff pings
    // keepAlive faster than the idle window elapses.
    for (var i = 0; i < 4; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      server.keepAlive();
    }
    expect(
      server.isRunning,
      isTrue,
      reason: 'keepAlive must reset the idle clock, not just extend it once',
    );

    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(
      server.isRunning,
      isFalse,
      reason: 'once keepAlive stops arriving, idle shutdown still applies',
    );
  });

  test(
    'controller shutdown stops the server for the matching serverId',
    () async {
      final server = serverFor();
      await server.start();

      await server.shutdown('other-server');
      expect(server.isRunning, isTrue);

      await server.shutdown('server-1');
      expect(server.isRunning, isFalse);
    },
  );

  test('currentSnapshot exposes the active session while running', () async {
    final server = serverFor();
    expect(await server.currentSnapshot(), isNull);

    await server.start();
    final snapshot = await server.currentSnapshot();
    expect(snapshot, isNotNull);
    expect(snapshot!.serverId, 'server-1');

    await server.stopServer();
    expect(await server.currentSnapshot(), isNull);
  });

  group('LAN address selection', () {
    InternetAddress addr(String ip) => InternetAddress(ip);

    test('prefers a private address on the Wi-Fi interface', () {
      final selected = PhoneMediaFileServer.selectLanAddress([
        (name: 'pdp_ip0', addresses: [addr('100.64.11.22')]),
        (name: 'en0', addresses: [addr('192.168.1.10')]),
      ]);
      expect(selected?.address, '192.168.1.10');
    });

    test('falls back to a private address on other interfaces', () {
      final selected = PhoneMediaFileServer.selectLanAddress([
        (name: 'eth0', addresses: [addr('10.0.0.5')]),
      ]);
      expect(selected?.address, '10.0.0.5');
    });

    test('never selects a public or carrier address', () {
      final selected = PhoneMediaFileServer.selectLanAddress([
        (name: 'pdp_ip0', addresses: [addr('100.64.11.22')]),
        (name: 'rmnet0', addresses: [addr('203.0.113.9')]),
        (name: 'wlan0', addresses: [addr('203.0.113.10')]),
      ]);
      expect(selected, isNull);
    });

    test('start throws when no private LAN address exists', () async {
      final server = PhoneMediaFileServer(
        snapshot: snapshotFor(),
        filePath: mediaFile.path,
        contentType: 'video/mp4',
        interfaceLister: () async => [
          (name: 'pdp_ip0', addresses: [addr('100.64.11.22')]),
        ],
      );
      await expectLater(server.start(), throwsA(isA<StateError>()));
      expect(server.isRunning, isFalse);
    });
  });

  test('isPrivateLanAddress accepts RFC1918 and loopback only', () {
    const accepted = ['192.168.1.20', '10.1.2.3', '172.16.0.9', '127.0.0.1'];
    const rejected = ['203.0.113.9', '100.64.11.22', '172.32.0.1', '8.8.8.8'];
    for (final ip in accepted) {
      expect(
        PhoneMediaFileServer.isPrivateLanAddress(InternetAddress(ip)),
        isTrue,
        reason: '$ip should be accepted',
      );
    }
    for (final ip in rejected) {
      expect(
        PhoneMediaFileServer.isPrivateLanAddress(InternetAddress(ip)),
        isFalse,
        reason: '$ip should be rejected',
      );
    }
  });

  group('diagnostics hardening', () {
    test('caps request_rejected events per window so a LAN flooder cannot '
        'spam the diagnostics pipeline', () async {
      final events = <(String, Map<String, Object?>)>[];
      final server = PhoneMediaFileServer(
        snapshot: snapshotFor(),
        filePath: mediaFile.path,
        contentType: 'video/mp4',
        bindAddress: InternetAddress.loopbackIPv4,
        sessionToken: 'test-session-token',
        onSessionEvent: (event, data) => events.add((event, data)),
      );
      final url = await server.start();
      addTearDown(server.stopServer);

      const attempts = PhoneMediaFileServer.maxRejectedEventsPerWindow + 5;
      for (var i = 0; i < attempts; i++) {
        final response = await request(
          url.replace(path: '/m/wrong-token/media'),
        );
        expect(response.statusCode, HttpStatus.notFound);
      }

      final rejected = events.where((e) => e.$1 == 'request_rejected').toList();
      expect(
        rejected.length,
        PhoneMediaFileServer.maxRejectedEventsPerWindow,
        reason: 'rejections beyond the window cap must be suppressed',
      );

      await server.stopServer();
      final suppressed = events
          .where((e) => e.$1 == 'request_rejected_suppressed')
          .toList();
      expect(suppressed, hasLength(1));
      expect(suppressed.single.$2['suppressedCount'], 5);
    });

    test('suppression counter resets when the window rolls over', () async {
      final events = <(String, Map<String, Object?>)>[];
      // Anchored to real time: the snapshot's expiry/idle checks compare
      // against this fake clock, so it must stay inside the grant window.
      var now = DateTime.now();
      final server = PhoneMediaFileServer(
        snapshot: snapshotFor(),
        filePath: mediaFile.path,
        contentType: 'video/mp4',
        bindAddress: InternetAddress.loopbackIPv4,
        sessionToken: 'test-session-token',
        now: () => now,
        onSessionEvent: (event, data) => events.add((event, data)),
      );
      final url = await server.start();
      addTearDown(server.stopServer);

      const cap = PhoneMediaFileServer.maxRejectedEventsPerWindow;
      for (var i = 0; i < cap + 3; i++) {
        await request(url.replace(path: '/m/wrong-token/media'));
      }
      expect(events.where((e) => e.$1 == 'request_rejected').length, cap);

      now = now.add(
        PhoneMediaFileServer.rejectedEventWindow + const Duration(seconds: 1),
      );
      await request(url.replace(path: '/m/wrong-token/media'));

      final suppressed = events
          .where((e) => e.$1 == 'request_rejected_suppressed')
          .toList();
      expect(suppressed, hasLength(1));
      expect(suppressed.single.$2['suppressedCount'], 3);
      expect(
        events.where((e) => e.$1 == 'request_rejected').length,
        cap + 1,
        reason: 'new window admits fresh request_rejected events',
      );
    });
  });

  group('entity tag', () {
    test('does not embed the file modification time', () async {
      final server = serverFor();
      final url = await server.start();
      addTearDown(server.stopServer);

      final response = await request(url, method: 'HEAD');
      final etag = response.headers.value(HttpHeaders.etagHeader);
      expect(etag, isNotNull);
      final stat = await mediaFile.stat();
      expect(
        etag,
        isNot(contains('${stat.modified.millisecondsSinceEpoch}')),
        reason: 'ETag must not leak the file mtime',
      );
    });

    test('is stable across requests within one session', () async {
      final server = serverFor();
      final url = await server.start();
      addTearDown(server.stopServer);

      final first = await request(url, method: 'HEAD');
      final second = await request(url, method: 'HEAD');
      expect(
        first.headers.value(HttpHeaders.etagHeader),
        second.headers.value(HttpHeaders.etagHeader),
      );
    });

    test('differs across server instances for the same file', () async {
      final serverA = serverFor();
      final serverB = serverFor();
      final urlA = await serverA.start();
      final urlB = await serverB.start();
      addTearDown(serverA.stopServer);
      addTearDown(serverB.stopServer);

      final a = await request(urlA, method: 'HEAD');
      final b = await request(urlB, method: 'HEAD');
      expect(
        a.headers.value(HttpHeaders.etagHeader),
        isNot(b.headers.value(HttpHeaders.etagHeader)),
        reason: 'per-session nonce keeps the ETag unlinkable to file state',
      );
    });
  });

  test('mediaUrl never appears in diagnostic toString output', () async {
    final server = serverFor();
    final url = await server.start();
    addTearDown(server.stopServer);

    expect(server.toString(), isNot(contains('test-session-token')));
    expect(server.toString(), isNot(contains(url.toString())));
    expect(server.toString(), isNot(contains(mediaFile.path)));
  });
}
