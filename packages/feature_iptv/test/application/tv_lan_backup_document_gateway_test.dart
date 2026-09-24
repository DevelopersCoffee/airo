import 'package:feature_iptv/application/tv_lan_backup_document_gateway.dart';
import 'package:feature_iptv/application/tv_lan_backup_ui_host.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_playlist_export/platform_playlist_export.dart';

void main() {
  const document = AiroBackupDocument(
    fileName: 'backup.json',
    mediaType: 'application/json',
    contents: '{}',
  );

  test('delegates export and import to the UI host', () async {
    final host = _RecordingHost();
    final gateway = TvLanBackupDocumentGateway(host: host);

    expect(await gateway.save(document), isTrue);
    expect(await gateway.share(document), isTrue);
    expect(await gateway.pick(), same(document));
    expect(host.exportCalls, 2);
    expect(host.importCalls, 1);
  });

  test('unavailable host reports failure', () async {
    const gateway = TvLanBackupDocumentGateway(
      host: UnavailableTvLanBackupUiHost(),
    );

    expect(await gateway.save(document), isFalse);
    expect(await gateway.pick(), isNull);
  });
}

class _RecordingHost implements TvLanBackupUiHost {
  int exportCalls = 0;
  int importCalls = 0;

  @override
  Future<bool> exportBackup(AiroBackupDocument document) async {
    exportCalls++;
    return true;
  }

  @override
  Future<AiroBackupDocument?> importBackup() async {
    importCalls++;
    return const AiroBackupDocument(
      fileName: 'backup.json',
      mediaType: 'application/json',
      contents: '{}',
    );
  }
}
