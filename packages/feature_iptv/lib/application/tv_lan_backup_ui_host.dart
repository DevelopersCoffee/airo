import 'package:platform_playlist_export/platform_playlist_export.dart';

/// Presents LAN backup QR sessions from a mounted widget tree.
///
/// [BackupRestoreSection] registers a host while visible so
/// [TvLanBackupDocumentGateway] can open dialogs without a global navigator.
abstract interface class TvLanBackupUiHost {
  Future<bool> exportBackup(AiroBackupDocument document);

  Future<AiroBackupDocument?> importBackup();
}

class UnavailableTvLanBackupUiHost implements TvLanBackupUiHost {
  const UnavailableTvLanBackupUiHost();

  @override
  Future<bool> exportBackup(AiroBackupDocument document) async => false;

  @override
  Future<AiroBackupDocument?> importBackup() async => null;
}
