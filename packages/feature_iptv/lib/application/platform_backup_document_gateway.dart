import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:platform_playlist_export/platform_playlist_export.dart';
import 'package:share_plus/share_plus.dart';

typedef BackupDocumentSaver =
    Future<void> Function(AiroBackupDocument document);
typedef BackupDocumentSharer =
    Future<void> Function(AiroBackupDocument document);
typedef BackupDocumentPicker = Future<AiroBackupDocument?> Function();

class PlatformBackupDocumentGateway implements AiroBackupDocumentGateway {
  const PlatformBackupDocumentGateway({
    this.saver = _save,
    this.sharer = _share,
    this.picker = _pick,
  });

  final BackupDocumentSaver saver;
  final BackupDocumentSharer sharer;
  final BackupDocumentPicker picker;

  @override
  Future<void> save(AiroBackupDocument document) => saver(document);

  @override
  Future<void> share(AiroBackupDocument document) => sharer(document);

  @override
  Future<AiroBackupDocument?> pick() => picker();

  static Future<void> _save(AiroBackupDocument document) async {
    await FilePicker.saveFile(
      dialogTitle: 'Save Airo TV backup',
      fileName: document.fileName,
      type: FileType.custom,
      allowedExtensions: const ['json'],
      bytes: Uint8List.fromList(utf8.encode(document.contents)),
    );
  }

  static Future<void> _share(AiroBackupDocument document) async {
    await SharePlus.instance.share(
      ShareParams(
        subject: 'Airo TV backup',
        files: [
          XFile.fromData(
            Uint8List.fromList(utf8.encode(document.contents)),
            mimeType: document.mediaType,
            name: document.fileName,
          ),
        ],
      ),
    );
  }

  static Future<AiroBackupDocument?> _pick() async {
    final result = await FilePicker.pickFiles(
      dialogTitle: 'Choose an Airo TV backup',
      type: FileType.custom,
      allowedExtensions: const ['json'],
      allowMultiple: false,
      withData: true,
    );
    final file = result?.files.singleOrNull;
    if (file == null) return null;
    final bytes = file.bytes;
    if (bytes == null) throw StateError('backup_file_bytes_unavailable');
    return AiroBackupDocument(
      fileName: file.name,
      mediaType: 'application/json',
      contents: utf8.decode(bytes),
    );
  }
}
