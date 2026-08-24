import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

import '../../capture/domain/meeting_processing_job.dart';
import 'audio_import_progress.dart';
import 'youtube_audio_downloader.dart';

export 'audio_import_progress.dart';
export 'youtube_audio_downloader.dart' show YoutubeAudioImport;

/// Picks a local audio file or downloads a podcast / YouTube URL into a path
/// the processing queue can transcribe.
class AudioImportService {
  AudioImportService({
    FilePickerPick? pickFile,
    AudioDownloader? downloader,
    YoutubeDownloader? youtubeDownloader,
  }) : _pickFile = pickFile ?? _defaultPick,
       _downloader = downloader ?? _dioDownload,
       _youtubeDownloader = youtubeDownloader ?? _defaultYoutubeDownload;

  final FilePickerPick _pickFile;
  final AudioDownloader _downloader;
  final YoutubeDownloader _youtubeDownloader;

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

  /// True for `youtube.com`, `youtu.be`, and `youtube-nocookie.com` watch URLs.
  bool isYoutubeUrl(String value) => extractYoutubeVideoId(value) != null;

  String titleFromPath(String path) {
    final name = p.basenameWithoutExtension(path).trim();
    return name.isEmpty ? 'Imported audio' : name.replaceAll('_', ' ');
  }

  String titleFromUrl(String url) {
    if (isYoutubeUrl(url)) return 'YouTube audio';
    final uri = Uri.tryParse(url.trim());
    final name = uri == null ? '' : p.basenameWithoutExtension(uri.path).trim();
    if (name.isNotEmpty) return name.replaceAll('_', ' ');
    return 'Podcast';
  }

  /// Opens the system file picker. Returns file bytes when the platform allows
  /// (macOS sandbox) so callers can write into the app container.
  Future<PlatformFile?> pickLocalAudioFile() async {
    final file = await _pickFile(
      type: FileType.custom,
      allowedExtensions: supportedExtensions.toList()..sort(),
    );
    if (file == null) return null;
    if (file.path != null && !isSupportedPath(file.path!)) {
      throw StateError('Unsupported audio type: ${p.extension(file.path!)}');
    }
    if (file.name.isNotEmpty && !isSupportedPath(file.name)) {
      throw StateError('Unsupported audio type: ${p.extension(file.name)}');
    }
    return file;
  }

  /// Legacy helper — returns a host path when available (tests / non-sandbox).
  Future<String?> pickLocalAudio() async {
    final file = await pickLocalAudioFile();
    return file?.path;
  }

  /// Writes a picker result into [destPath] inside the app sandbox.
  Future<String> stagePickedFile(
    PlatformFile file,
    String destPath, {
    AudioImportProgressCallback? onProgress,
  }) async {
    onProgress?.call(
      const AudioImportProgress(stage: AudioImportStage.staging),
    );
    final dest = File(destPath);
    await dest.parent.create(recursive: true);
    final bytes = await file.readAsBytes();
    if (bytes.isNotEmpty) {
      await dest.writeAsBytes(bytes, flush: true);
    } else if (file.path != null && file.path!.isNotEmpty) {
      await File(file.path!).copy(destPath);
    } else {
      throw StateError('Could not read picked audio (no bytes or path)');
    }
    if (!dest.existsSync() || dest.lengthSync() == 0) {
      throw StateError('Imported audio is empty at $destPath');
    }
    return destPath;
  }

  Future<String> downloadRemote({
    required String url,
    required String destPath,
    AudioImportProgressCallback? onProgress,
  }) async {
    if (!isHttpUrl(url)) {
      throw ArgumentError('Not an http(s) audio URL: $url');
    }
    final file = File(destPath);
    await file.parent.create(recursive: true);
    onProgress?.call(
      AudioImportProgress(
        stage: AudioImportStage.downloading,
        title: titleFromUrl(url),
      ),
    );
    await _downloader(url.trim(), destPath, onProgress);
    if (!file.existsSync() || file.lengthSync() == 0) {
      throw StateError('Download produced no audio at $destPath');
    }
    return destPath;
  }

  /// Downloads audio from a YouTube watch URL for on-device transcription.
  Future<YoutubeAudioImport> downloadYoutube({
    required String url,
    required String destPath,
    AudioImportProgressCallback? onProgress,
  }) {
    if (!isYoutubeUrl(url)) {
      throw ArgumentError('Not a YouTube URL: $url');
    }
    return _youtubeDownloader(url.trim(), destPath, onProgress);
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

typedef AudioDownloader =
    Future<void> Function(
      String url,
      String destPath,
      AudioImportProgressCallback? onProgress,
    );

typedef YoutubeDownloader =
    Future<YoutubeAudioImport> Function(
      String url,
      String destPath,
      AudioImportProgressCallback? onProgress,
    );

Future<PlatformFile?> _defaultPick({
  FileType type = FileType.any,
  List<String>? allowedExtensions,
}) {
  return FilePicker.pickFile(
    type: type,
    allowedExtensions: allowedExtensions,
  );
}

Future<void> _dioDownload(
  String url,
  String destPath,
  AudioImportProgressCallback? onProgress,
) async {
  final dio = Dio(
    BaseOptions(
      followRedirects: true,
      maxRedirects: 5,
      receiveTimeout: const Duration(minutes: 15),
      connectTimeout: const Duration(seconds: 30),
    ),
  );
  await dio.download(
    url,
    destPath,
    onReceiveProgress: (received, total) {
      onProgress?.call(
        AudioImportProgress(
          stage: AudioImportStage.downloading,
          receivedBytes: received,
          totalBytes: total,
        ),
      );
    },
  );
}

Future<YoutubeAudioImport> _defaultYoutubeDownload(
  String url,
  String destPath,
  AudioImportProgressCallback? onProgress,
) async {
  final videoId = extractYoutubeVideoId(url);
  if (videoId == null) {
    throw ArgumentError('Not a YouTube URL: $url');
  }
  final client = YoutubeAudioDownloader();
  try {
    return await client.download(
      videoId: videoId,
      destPath: destPath,
      onProgress: onProgress,
    );
  } finally {
    client.close();
  }
}
