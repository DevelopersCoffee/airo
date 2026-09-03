import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:platform_playlist_export/platform_playlist_export.dart';
import 'package:platform_worker_jobs/platform_worker_jobs.dart';
import 'package:share_plus/share_plus.dart';

typedef BackupDocumentSaver =
    Future<bool> Function(AiroBackupDocument document);
typedef BackupDocumentSharer =
    Future<bool> Function(AiroBackupDocument document);
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
  Future<bool> save(AiroBackupDocument document) => saver(document);

  @override
  Future<bool> share(AiroBackupDocument document) => sharer(document);

  @override
  Future<AiroBackupDocument?> pick() => picker();

  static Future<bool> _save(AiroBackupDocument document) async {
    // A null destination means the dialog was cancelled, or — on TV, where
    // `file_picker` is dependency-overridden to a stub — that there was
    // never a dialog at all. Either way nothing reached disk.
    final destination = await FilePicker.saveFile(
      dialogTitle: 'Save Aika Stream backup',
      fileName: document.fileName,
      type: FileType.custom,
      allowedExtensions: const ['json'],
      bytes: Uint8List.fromList(utf8.encode(document.contents)),
    );
    return destination != null;
  }

  static Future<bool> _share(AiroBackupDocument document) async {
    // `dismissed` and `unavailable` (the TV stub's only answer) both mean
    // the document was not handed off.
    final result = await SharePlus.instance.share(
      ShareParams(
        subject: 'Aika Stream backup',
        files: [
          XFile.fromData(
            Uint8List.fromList(utf8.encode(document.contents)),
            mimeType: document.mediaType,
            name: document.fileName,
          ),
        ],
      ),
    );
    return result.status == ShareResultStatus.success;
  }

  static Future<AiroBackupDocument?> _pick() async {
    final file = await FilePicker.pickFile(
      dialogTitle: 'Choose an Aika Stream backup',
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    final contents = bytes.length > 50 * 1024
        ? await const AiroWorkerExecutor().run(
            debugName: 'decode_airo_backup',
            kind: AiroWorkerJobKind.deviceSync,
            computation: () => utf8.decode(bytes),
          )
        : utf8.decode(bytes);
    return AiroBackupDocument(
      fileName: file.name,
      mediaType: 'application/json',
      contents: contents,
    );
  }
}
