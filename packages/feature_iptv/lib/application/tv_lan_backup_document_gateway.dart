import 'package:platform_playlist_export/platform_playlist_export.dart';

import 'tv_lan_backup_ui_host.dart';

/// TV-safe backup I/O through short-lived LAN QR sessions instead of
/// stubbed `file_picker` / `share_plus`.
class TvLanBackupDocumentGateway implements AiroBackupDocumentGateway {
  const TvLanBackupDocumentGateway({required this.host});

  final TvLanBackupUiHost host;

  @override
  Future<bool> save(AiroBackupDocument document) => host.exportBackup(document);

  @override
  Future<bool> share(AiroBackupDocument document) =>
      host.exportBackup(document);

  @override
  Future<AiroBackupDocument?> pick() => host.importBackup();
}
