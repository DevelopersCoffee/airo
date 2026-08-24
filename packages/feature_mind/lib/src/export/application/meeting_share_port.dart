import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../domain/meeting_export_models.dart';

/// Copy / share meeting artifacts (transcript text, audio, markdown files).
abstract interface class MeetingSharePort {
  Future<void> copyText(String text);

  /// Hands one or more on-disk files to the platform share sheet.
  Future<bool> shareFiles(List<String> paths, {String? subject});

  /// Shares markdown produced in memory (no temp file on disk).
  Future<bool> shareMarkdown({
    required String filename,
    required String markdown,
    String? subject,
  });
}

class PlatformMeetingSharePort implements MeetingSharePort {
  const PlatformMeetingSharePort({
    this.clipboard,
    this.fileSharer,
    this.markdownSharer,
  });

  final Future<void> Function(String text)? clipboard;
  final Future<bool> Function(List<String> paths, {String? subject})?
  fileSharer;
  final Future<bool> Function({
    required String filename,
    required String markdown,
    String? subject,
  })?
  markdownSharer;

  @override
  Future<void> copyText(String text) {
    if (clipboard != null) return clipboard!(text);
    return Clipboard.setData(ClipboardData(text: text));
  }

  @override
  Future<bool> shareFiles(List<String> paths, {String? subject}) {
    if (fileSharer != null) {
      return fileSharer!(paths, subject: subject);
    }
    return _shareFiles(paths, subject: subject);
  }

  @override
  Future<bool> shareMarkdown({
    required String filename,
    required String markdown,
    String? subject,
  }) {
    if (markdownSharer != null) {
      return markdownSharer!(
        filename: filename,
        markdown: markdown,
        subject: subject,
      );
    }
    return _shareMarkdown(
      filename: filename,
      markdown: markdown,
      subject: subject,
    );
  }

  static Future<bool> _shareFiles(
    List<String> paths, {
    String? subject,
  }) async {
    if (kIsWeb || paths.isEmpty) return false;
    final files = <XFile>[];
    for (final path in paths) {
      if (path.isEmpty) continue;
      final file = File(path);
      if (!file.existsSync()) continue;
      files.add(XFile(path));
    }
    if (files.isEmpty) return false;
    final result = await SharePlus.instance.share(
      ShareParams(subject: subject, files: files),
    );
    return result.status != ShareResultStatus.unavailable;
  }

  static Future<bool> _shareMarkdown({
    required String filename,
    required String markdown,
    String? subject,
  }) async {
    final result = await SharePlus.instance.share(
      ShareParams(
        subject: subject ?? filename,
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
}

class MemoryMeetingSharePort implements MeetingSharePort {
  String? lastCopied;
  List<String>? lastSharedPaths;
  String? lastSharedMarkdown;
  String? lastFilename;

  @override
  Future<void> copyText(String text) async {
    lastCopied = text;
  }

  @override
  Future<bool> shareFiles(List<String> paths, {String? subject}) async {
    lastSharedPaths = List<String>.from(paths);
    return true;
  }

  @override
  Future<bool> shareMarkdown({
    required String filename,
    required String markdown,
    String? subject,
  }) async {
    lastFilename = filename;
    lastSharedMarkdown = markdown;
    return true;
  }
}

/// Picks one markdown file from an export bundle for single-file sharing.
String? transcriptMarkdownFromBundle(MeetingExportBundle bundle) =>
    bundle.files['transcript.md'];

String? minutesMarkdownFromBundle(MeetingExportBundle bundle) =>
    bundle.files['mom.md'];
