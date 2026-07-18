@Tags(['soak'])
library;

import 'dart:io';

import 'package:core_media_routing/core_media_routing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_player/platform_player.dart';

/// One-off CV-033 soak: serves a sparse 5 GB file and seeks across it.
/// Run explicitly with: flutter test --tags soak
void main() {
  test('5 GB file streams with correct far-offset range responses', () async {
    final tempDir = await Directory.systemTemp.createTemp('cv033_soak');
    addTearDown(() => tempDir.delete(recursive: true));

    const fiveGb = 5 * 1024 * 1024 * 1024;
    final mediaFile = File('${tempDir.path}/movie.mp4');
    // Sparse file: write one marker byte at the end so length is 5 GB
    // without materializing 5 GB on disk (APFS keeps holes sparse).
    final raf = await mediaFile.open(mode: FileMode.write);
    await raf.setPosition(fiveGb - 1);
    await raf.writeByte(0x42);
    await raf.close();
    expect(await mediaFile.length(), fiveGb);

    final now = DateTime.now();
    final server = PhoneMediaFileServer(
      snapshot: AiroTemporaryMobileServerSnapshot(
        serverId: 'soak-server',
        hostNodeId: 'phone-node',
        locationId: 'loc-soak',
        mediaId: 'media-soak',
        accessGrant: AiroRouteAccessGrant(
          grantId: 'grant-soak',
          locationId: 'loc-soak',
          audienceNodeId: 'tv-node',
          handle: AiroRouteAccessHandle.redacted('soak-grant-handle'),
          issuedAt: now,
          expiresAt: now.add(const Duration(hours: 1)),
          scopes: const {
            AiroRouteAccessScope.playbackRead,
            AiroRouteAccessScope.rangeRead,
            AiroRouteAccessScope.probeRead,
          },
        ),
        startedAt: now,
        expiresAt: now.add(const Duration(hours: 1)),
        batteryPercent: 100,
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
      ),
      filePath: mediaFile.path,
      contentType: 'video/mp4',
      bindAddress: InternetAddress.loopbackIPv4,
      sessionToken: 'soak-token',
    );

    final url = await server.start();
    addTearDown(server.stopServer);

    final client = HttpClient();
    addTearDown(client.close);

    Future<HttpClientResponse> range(String header) async {
      final req = await client.getUrl(url);
      req.headers.set(HttpHeaders.rangeHeader, header);
      return req.close();
    }

    // HEAD probe advertises the full 5 GB entity.
    final headReq = await client.openUrl('HEAD', url);
    final headResp = await headReq.close();
    expect(headResp.statusCode, HttpStatus.ok);
    expect(headResp.contentLength, fiveGb);
    await headResp.drain<void>();

    // Seek to ~4.5 GB (beyond 32-bit offsets) — mid-file window.
    const midStart = 4838400000;
    final mid = await range('bytes=$midStart-${midStart + 1023}');
    expect(mid.statusCode, HttpStatus.partialContent);
    expect(
      mid.headers.value(HttpHeaders.contentRangeHeader),
      'bytes $midStart-${midStart + 1023}/$fiveGb',
    );
    final midBody = await mid.fold<List<int>>([], (a, b) => a..addAll(b));
    expect(midBody.length, 1024);
    expect(midBody.every((b) => b == 0), isTrue);

    // Suffix seek: last 512 bytes must include the marker byte at the end.
    final tail = await range('bytes=-512');
    expect(tail.statusCode, HttpStatus.partialContent);
    expect(
      tail.headers.value(HttpHeaders.contentRangeHeader),
      'bytes ${fiveGb - 512}-${fiveGb - 1}/$fiveGb',
    );
    final tailBody = await tail.fold<List<int>>([], (a, b) => a..addAll(b));
    expect(tailBody.length, 512);
    expect(tailBody.last, 0x42);

    // Sequential window near the start (receiver buffering pattern).
    final head = await range('bytes=0-1048575');
    expect(head.statusCode, HttpStatus.partialContent);
    final headBody = await head.fold<int>(0, (n, b) => n + b.length);
    expect(headBody, 1048576);
  }, timeout: const Timeout(Duration(minutes: 3)));
}
