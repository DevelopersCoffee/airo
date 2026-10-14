import 'dart:convert';
import 'dart:io';

import 'package:airo_background_downloads/airo_background_downloads.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late SecurityContext serverContext;
  late Directory tempDir;

  setUpAll(() async {
    final certDir = await Directory.systemTemp.createTemp('airo-bg-dl-certs-');
    final certPath = '${certDir.path}/server.crt';
    final keyPath = '${certDir.path}/server.key';
    final result = await Process.run('openssl', [
      'req',
      '-x509',
      '-newkey',
      'rsa:2048',
      '-nodes',
      '-keyout',
      keyPath,
      '-out',
      certPath,
      '-days',
      '1',
      '-subj',
      '/CN=localhost',
    ]);
    expect(result.exitCode, equals(0), reason: result.stderr.toString());

    serverContext = SecurityContext()
      ..useCertificateChain(certPath)
      ..usePrivateKey(keyPath);
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('http-dl-');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  HttpClient testClient() {
    final client = HttpClient(context: SecurityContext())
      ..badCertificateCallback = (cert, host, port) => true;
    return client;
  }

  Future<Uri> bindServer(
    Future<void> Function(HttpRequest request) handler,
  ) async {
    final server = await HttpServer.bindSecure(
      InternetAddress.loopbackIPv4,
      0,
      serverContext,
    );
    addTearDown(() async => server.close(force: true));
    server.listen(handler);
    return Uri.parse('https://${server.address.host}:${server.port}/file');
  }

  Future<DownloadProgress> waitForTerminal(
    HttpBackgroundDownloads downloads,
    String artifactId,
  ) async {
    return downloads.events.firstWhere(
      (event) =>
          event.artifactId == artifactId &&
          (event.status == DownloadStatus.completed ||
              event.status == DownloadStatus.failed),
    );
  }

  test('wrong hash fails and does not replace destination', () async {
    final payload = utf8.encode('destination-should-survive');
    final wrongHash = '0' * 64;
    final destination = File('${tempDir.path}/model.bin');
    await destination.writeAsBytes(utf8.encode('original-bytes'));

    final url = await bindServer((request) async {
      request.response
        ..statusCode = HttpStatus.ok
        ..contentLength = payload.length
        ..add(payload)
        ..close();
    });

    final downloads = HttpBackgroundDownloads(clientFactory: testClient);
    await downloads.enqueue(
      DownloadArtifactRequest(
        artifactId: 'bad-hash',
        source: url,
        destinationPath: destination.path,
        expectedBytes: payload.length,
        expectedSha256: wrongHash,
      ),
    );

    final terminal = await waitForTerminal(downloads, 'bad-hash');
    expect(terminal.status, DownloadStatus.failed);
    expect(terminal.failure?.code, DownloadFailureCode.integrityMismatch);
    expect(await destination.readAsString(), equals('original-bytes'));
    expect(File('${destination.path}.partial').existsSync(), isTrue);
  });

  test(
    'server ignores Range (200) and restarts without corrupt append',
    () async {
      final payload = utf8.encode('full-payload-after-200-restart');
      final destination = File('${tempDir.path}/file.bin');
      final partial = File('${destination.path}.partial');
      await partial.writeAsBytes(payload.sublist(0, 5));

      var requestCount = 0;
      final url = await bindServer((request) async {
        requestCount += 1;
        if (requestCount == 1) {
          expect(
            request.headers.value(HttpHeaders.rangeHeader),
            equals('bytes=5-'),
          );
        }
        request.response
          ..statusCode = HttpStatus.ok
          ..contentLength = payload.length
          ..add(payload)
          ..close();
      });

      final downloads = HttpBackgroundDownloads(clientFactory: testClient);
      await downloads.enqueue(
        DownloadArtifactRequest(
          artifactId: 'ignore-range',
          source: url,
          destinationPath: destination.path,
          expectedBytes: payload.length,
        ),
      );

      final terminal = await waitForTerminal(downloads, 'ignore-range');
      expect(terminal.status, DownloadStatus.completed);
      expect(await destination.readAsBytes(), equals(payload));
      expect(requestCount, equals(1));
    },
  );

  test('mismatched Content-Range restarts download cleanly', () async {
    final payload = utf8.encode('mismatch-content-range-restart');
    final destination = File('${tempDir.path}/file.bin');
    final partial = File('${destination.path}.partial');
    await partial.writeAsBytes(payload.sublist(0, 4));

    var requestCount = 0;
    final url = await bindServer((request) async {
      requestCount += 1;
      if (requestCount == 1) {
        request.response
          ..statusCode = HttpStatus.partialContent
          ..headers.set(
            HttpHeaders.contentRangeHeader,
            'bytes 0-3/${payload.length}',
          )
          ..contentLength = 4
          ..add(payload.sublist(0, 4))
          ..close();
        return;
      }
      expect(request.headers.value(HttpHeaders.rangeHeader), isNull);
      request.response
        ..statusCode = HttpStatus.ok
        ..contentLength = payload.length
        ..add(payload)
        ..close();
    });

    final downloads = HttpBackgroundDownloads(clientFactory: testClient);
    await downloads.enqueue(
      DownloadArtifactRequest(
        artifactId: 'bad-range',
        source: url,
        destinationPath: destination.path,
        expectedBytes: payload.length,
      ),
    );

    final terminal = await waitForTerminal(downloads, 'bad-range');
    expect(terminal.status, DownloadStatus.completed);
    expect(await destination.readAsBytes(), equals(payload));
    expect(requestCount, equals(2));
  });

  test('valid 206 resume appends bytes correctly', () async {
    final payload = utf8.encode('valid-206-resume-append-test');
    final destination = File('${tempDir.path}/file.bin');
    final partial = File('${destination.path}.partial');
    final firstChunk = payload.sublist(0, 10);
    await partial.writeAsBytes(firstChunk);

    var requestCount = 0;
    final url = await bindServer((request) async {
      requestCount += 1;
      expect(requestCount, equals(1));
      expect(
        request.headers.value(HttpHeaders.rangeHeader),
        equals('bytes=${firstChunk.length}-'),
      );
      final remainder = payload.sublist(firstChunk.length);
      request.response
        ..statusCode = HttpStatus.partialContent
        ..headers.set(
          HttpHeaders.contentRangeHeader,
          'bytes ${firstChunk.length}-${payload.length - 1}/${payload.length}',
        )
        ..contentLength = remainder.length
        ..add(remainder)
        ..close();
    });

    final downloads = HttpBackgroundDownloads(clientFactory: testClient);
    await downloads.enqueue(
      DownloadArtifactRequest(
        artifactId: 'resume-206',
        source: url,
        destinationPath: destination.path,
        expectedBytes: payload.length,
      ),
    );

    final terminal = await waitForTerminal(downloads, 'resume-206');
    expect(terminal.status, DownloadStatus.completed);
    expect(await destination.readAsBytes(), equals(payload));
  });

  test(
    'simulated crash between verify and rename keeps old destination',
    () async {
      final payload = utf8.encode('verified-but-not-committed');
      final destination = File('${tempDir.path}/model.bin');
      await destination.writeAsString('previous-version');

      final url = await bindServer((request) async {
        request.response
          ..statusCode = HttpStatus.ok
          ..contentLength = payload.length
          ..add(payload)
          ..close();
      });

      final downloads = HttpBackgroundDownloads(
        clientFactory: testClient,
        onBeforeCommitPartial: (_, _) async {
          throw StateError('simulated crash before rename');
        },
      );

      await downloads.enqueue(
        DownloadArtifactRequest(
          artifactId: 'crash-before-rename',
          source: url,
          destinationPath: destination.path,
          expectedBytes: payload.length,
        ),
      );

      final terminal = await waitForTerminal(downloads, 'crash-before-rename');
      expect(terminal.status, DownloadStatus.failed);
      expect(await destination.readAsString(), equals('previous-version'));
      expect(File('${destination.path}.partial').existsSync(), isTrue);
      expect(
        await File('${destination.path}.partial').readAsBytes(),
        equals(payload),
      );
    },
  );

  test('custom request headers are sent on outgoing HTTP request', () async {
    final payload = utf8.encode('header-test');
    final destination = File('${tempDir.path}/file.bin');
    String? authorization;

    final url = await bindServer((request) async {
      authorization = request.headers.value('Authorization');
      request.response
        ..statusCode = HttpStatus.ok
        ..contentLength = payload.length
        ..add(payload)
        ..close();
    });

    final downloads = HttpBackgroundDownloads(clientFactory: testClient);
    await downloads.enqueue(
      DownloadArtifactRequest(
        artifactId: 'custom-headers',
        source: url,
        destinationPath: destination.path,
        expectedBytes: payload.length,
        headers: const {'Authorization': 'Bearer test-token'},
      ),
    );

    final terminal = await waitForTerminal(downloads, 'custom-headers');
    expect(terminal.status, DownloadStatus.completed);
    expect(authorization, equals('Bearer test-token'));
  });
}
