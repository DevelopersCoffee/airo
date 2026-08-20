import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

import '../../capture/domain/meeting_processing_job.dart';

/// Picks a local audio file or downloads a podcast URL into a path the
/// processing queue can transcribe.
class AudioImportService {
  AudioImportService({FilePickerPick? pickFile, AudioDownloader? downloader})
    : _pickFile = pickFile ?? _defaultPick,
      _downloader = downloader ?? _dioDownload;

  final FilePickerPick _pickFile;
  final AudioDownloader _downloader;

  static const supportedExtensions = <String>{
    'm4a',
    'm4b',
    'aac',
    'wav',
    'mp3',
    'ogg',
    'opus',
    'flac',
    'mp4',
    'webm',
    'wma',
    'aiff',
    'caf',
  };

  bool isSupportedPath(String path) {
    final ext = p.extension(path).toLowerCase().replaceAll('.', '');
    return supportedExtensions.contains(ext);
  }

  bool isHttpUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) return false;
    return uri.scheme == 'http' || uri.scheme == 'https';
  }

  String titleFromPath(String path) {
    final name = p.basenameWithoutExtension(path).trim();
    return name.isEmpty ? 'Imported audio' : name.replaceAll('_', ' ');
  }

  String titleFromUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    final name = uri == null ? '' : p.basenameWithoutExtension(uri.path).trim();
    if (name.isNotEmpty) return name.replaceAll('_', ' ');
    return 'Podcast';
  }

  Future<String?> pickLocalAudio() async {
    final file = await _pickFile(
      type: FileType.custom,
      allowedExtensions: supportedExtensions.toList()..sort(),
    );
    final path = file?.path;
    if (path == null || path.isEmpty) return null;
    if (!isSupportedPath(path)) {
      throw StateError('Unsupported audio type: ${p.extension(path)}');
    }
    return path;
  }

  Future<String> downloadRemote({
    required String url,
    required String destPath,
  }) async {
    if (!isHttpUrl(url)) {
      throw ArgumentError('Not an http(s) audio URL: $url');
    }
    final file = File(destPath);
    await file.parent.create(recursive: true);
    await _downloader(url.trim(), destPath);
    if (!file.existsSync() || file.lengthSync() == 0) {
      throw StateError('Download produced no audio at $destPath');
    }
    return destPath;
  }

  MeetingProcessingJob jobFor({
    required String audioPath,
    required String title,
    required MeetingProcessingSource source,
    required int enqueuedAtMs,
    String? id,
  }) {
    return MeetingProcessingJob(
      id: id ?? 'import-$enqueuedAtMs',
      audioPath: audioPath,
      title: title,
      enqueuedAtMs: enqueuedAtMs,
      source: source,
    );
  }
}

typedef FilePickerPick =
    Future<PlatformFile?> Function({
      FileType type,
      List<String>? allowedExtensions,
    });

typedef AudioDownloader = Future<void> Function(String url, String destPath);

Future<PlatformFile?> _defaultPick({
  FileType type = FileType.any,
  List<String>? allowedExtensions,
}) {
  return FilePicker.pickFile(type: type, allowedExtensions: allowedExtensions);
}

Future<void> _dioDownload(String url, String destPath) async {
  final dio = Dio(
    BaseOptions(
      followRedirects: true,
      maxRedirects: 5,
      receiveTimeout: const Duration(minutes: 5),
    ),
  );
  await dio.download(url, destPath);
}
