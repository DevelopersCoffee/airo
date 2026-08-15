import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../domain/meeting_export_models.dart';

/// Where an export bundle ends up: on disk, or through the platform share
/// sheet.
///
/// Mirrors `PlatformBackupDocumentGateway`
/// (`feature_iptv/lib/application/platform_backup_document_gateway.dart`) —
/// same injectable-function shape over the same two plugins, so the
/// orchestration in `_save`/`_share` is swappable in a test without a
/// platform channel. That existing gateway is this feature's house pattern
/// for share-sheet + save-to-folder.
typedef MeetingExportSaver =
    Future<bool> Function(List<MeetingExportBundle> bundles);
typedef MeetingExportSharer =
    Future<bool> Function(List<MeetingExportBundle> bundles);

abstract interface class MeetingExportGateway {
  /// Writes every bundle to disk. Returns `false` if the user cancelled the
  /// folder/file picker, or there was nothing to save.
  Future<bool> saveToFolder(List<MeetingExportBundle> bundles);

  /// Hands every bundle's files to the platform share sheet in one call.
  Future<bool> share(List<MeetingExportBundle> bundles);
}

class PlatformMeetingExportGateway implements MeetingExportGateway {
  const PlatformMeetingExportGateway({
    this.saver = _save,
    this.sharer = _share,
  });

  final MeetingExportSaver saver;
  final MeetingExportSharer sharer;

  @override
  Future<bool> saveToFolder(List<MeetingExportBundle> bundles) =>
      saver(bundles);

  @override
  Future<bool> share(List<MeetingExportBundle> bundles) => sharer(bundles);

  /// Real folder-per-meeting on every platform with a filesystem the user can
  /// browse. Browsers have no folder to write into, so on web this falls
  /// back to one download per file, named `{folder}-{file}` so which meeting
  /// it came from is still obvious once it lands in Downloads.
  static Future<bool> _save(List<MeetingExportBundle> bundles) async {
    if (bundles.isEmpty) return false;

    if (kIsWeb) {
      var savedAny = false;
      for (final bundle in bundles) {
        for (final entry in bundle.files.entries) {
          final saved = await FilePicker.saveFile(
            dialogTitle: 'Save ${bundle.folderName}/${entry.key}',
            fileName: '${bundle.folderName}-${entry.key}',
            bytes: Uint8List.fromList(utf8.encode(entry.value)),
          );
          savedAny = savedAny || saved != null;
        }
      }
      return savedAny;
    }

    final root = await FilePicker.getDirectoryPath(
      dialogTitle: bundles.length == 1
          ? 'Choose a folder to export "${bundles.single.folderName}" into'
          : 'Choose a folder to export ${bundles.length} meetings into',
    );
    if (root == null) return false;

    for (final bundle in bundles) {
      final dir = Directory(p.join(root, bundle.folderName));
      await dir.create(recursive: true);
      for (final entry in bundle.files.entries) {
        await File(p.join(dir.path, entry.key)).writeAsString(entry.value);
      }
    }
    return true;
  }

  /// One share-sheet invocation for every file across every bundle. Most
  /// share targets have no concept of a folder, so files are flattened with
  /// the meeting's folder name as a prefix rather than nested.
  static Future<bool> _share(List<MeetingExportBundle> bundles) async {
    if (bundles.isEmpty) return false;
    final files = <XFile>[
      for (final bundle in bundles)
        for (final entry in bundle.files.entries)
          XFile.fromData(
            Uint8List.fromList(utf8.encode(entry.value)),
            mimeType: 'text/markdown',
            name: '${bundle.folderName}-${entry.key}',
          ),
    ];
    final result = await SharePlus.instance.share(
      ShareParams(
        subject: bundles.length == 1
            ? bundles.single.folderName
            : '${bundles.length} meetings',
        files: files,
      ),
    );
    return result.status != ShareResultStatus.unavailable;
  }
}
