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
}
