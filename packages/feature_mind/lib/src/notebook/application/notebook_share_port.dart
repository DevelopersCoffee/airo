import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

/// Copy / share / save a notebook markdown payload.
abstract interface class NotebookSharePort {
  Future<void> copyText(String text);
  Future<bool> shareMarkdown({
    required String filename,
    required String markdown,
  });
  Future<bool> saveMarkdown({
    required String filename,
    required String markdown,
  });
}

class PlatformNotebookSharePort implements NotebookSharePort {
  const PlatformNotebookSharePort({this.clipboard, this.sharer, this.saver});

  final Future<void> Function(String text)? clipboard;
  final Future<bool> Function(String filename, String markdown)? sharer;
  final Future<bool> Function(String filename, String markdown)? saver;

  @override
  Future<void> copyText(String text) {
    if (clipboard != null) return clipboard!(text);
    return Clipboard.setData(ClipboardData(text: text));
  }

  @override
  Future<bool> shareMarkdown({
    required String filename,
    required String markdown,
  }) {
    if (sharer != null) return sharer!(filename, markdown);
    return _share(filename, markdown);
  }

  @override
  Future<bool> saveMarkdown({
    required String filename,
    required String markdown,
  }) {
    if (saver != null) return saver!(filename, markdown);
    return _save(filename, markdown);
  }

  static Future<bool> _share(String filename, String markdown) async {
    final result = await SharePlus.instance.share(
      ShareParams(
        subject: filename,
        files: [
          XFile.fromData(
            Uint8List.fromList(utf8.encode(markdown)),
            mimeType: 'text/markdown',
            name: filename,
          ),
        ],
      ),
    );
    return result.status != ShareResultStatus.unavailable;
  }

  static Future<bool> _save(String filename, String markdown) async {
    final saved = await FilePicker.saveFile(
      dialogTitle: 'Save $filename',
      fileName: filename,
      bytes: Uint8List.fromList(utf8.encode(markdown)),
    );
    return saved != null || kIsWeb;
  }
}

class MemoryNotebookSharePort implements NotebookSharePort {
  String? lastCopied;
  String? lastShared;
  String? lastSaved;
  String? lastFilename;

  @override
  Future<void> copyText(String text) async {
    lastCopied = text;
  }

  @override
  Future<bool> shareMarkdown({
    required String filename,
    required String markdown,
  }) async {
    lastFilename = filename;
    lastShared = markdown;
    return true;
  }

  @override
  Future<bool> saveMarkdown({
    required String filename,
    required String markdown,
  }) async {
    lastFilename = filename;
    lastSaved = markdown;
    return true;
  }
}
