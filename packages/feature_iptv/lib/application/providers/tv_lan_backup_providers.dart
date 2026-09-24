import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_playlist_export/platform_playlist_export.dart';

import '../services/tv_lan_backup_export_server.dart';
import '../services/tv_lan_backup_import_server.dart';
import '../tv_lan_backup_ui_host.dart';

final tvLanBackupExportServerFactoryProvider =
    Provider<TvLanBackupExportServer Function(AiroBackupDocument document)>((
      ref,
    ) {
      return (document) => TvLanBackupExportServer(document: document);
    });

final tvLanBackupImportServerFactoryProvider =
    Provider<TvLanBackupImportServer Function()>((ref) {
      return TvLanBackupImportServer.new;
    });

class TvLanBackupUiHostNotifier extends Notifier<TvLanBackupUiHost> {
  @override
  TvLanBackupUiHost build() => const UnavailableTvLanBackupUiHost();

  void bind(TvLanBackupUiHost host) => state = host;

  void unbind() => state = const UnavailableTvLanBackupUiHost();
}

final tvLanBackupUiHostProvider =
    NotifierProvider<TvLanBackupUiHostNotifier, TvLanBackupUiHost>(
      TvLanBackupUiHostNotifier.new,
    );
