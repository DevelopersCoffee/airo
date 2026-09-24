import 'package:flutter/material.dart';
import 'package:platform_playlist_export/platform_playlist_export.dart';

import '../presentation/widgets/tv_backup_qr_dialog.dart';
import 'tv_lan_backup_ui_host.dart';

class WidgetTvLanBackupUiHost implements TvLanBackupUiHost {
  const WidgetTvLanBackupUiHost(this.context);

  final BuildContext context;

  @override
  Future<bool> exportBackup(AiroBackupDocument document) async {
    final available = await showDialog<bool>(
      context: context,
      builder: (_) => TvBackupExportQrDialog(document: document),
    );
    return available ?? false;
  }

  @override
  Future<AiroBackupDocument?> importBackup() {
    return showDialog<AiroBackupDocument>(
      context: context,
      builder: (_) => const TvBackupImportQrDialog(),
    );
  }
}
