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

  test('LAN share rejects unsupported schemes', () async {
    await expectLater(
      AiroLanSyncService().fetchShare(Uri.parse('ftp://example.test/x')),
      throwsA(isA<FormatException>()),
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
