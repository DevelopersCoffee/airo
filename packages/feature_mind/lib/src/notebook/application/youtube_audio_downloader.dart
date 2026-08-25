import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import 'audio_import_progress.dart';

/// Result of pulling audio from a YouTube watch URL into the app sandbox.
class YoutubeAudioImport {
  const YoutubeAudioImport({required this.path, required this.title});

  final String path;
  final String title;
}

/// Resolves a YouTube watch URL to a local audio file for transcription.
class YoutubeAudioDownloader {
  YoutubeAudioDownloader({YoutubeExplode? client})
    : _client = client ?? YoutubeExplode();

  final YoutubeExplode _client;

  /// Pulls the highest-quality MP4 audio stream into [destPath].
  ///
  /// [destPath] may omit the extension; `.m4a` is applied for MP4 audio.
  Future<YoutubeAudioImport> download({
    required String videoId,
    required String destPath,
    AudioImportProgressCallback? onProgress,
  }) async {
    onProgress?.call(
      const AudioImportProgress(stage: AudioImportStage.resolving),
    );

    try {
      final video = await _client.videos.get(videoId);
      final manifest = await _client.videos.streamsClient.getManifest(
        videoId,
        ytClients: [
          YoutubeApiClient.ios,
          YoutubeApiClient.androidSdkless,
        ],
      );
      final audio = _pickAudioStream(manifest);
      final outputPath = p.setExtension(destPath, '.m4a');
      final file = File(outputPath);
      await file.parent.create(recursive: true);
      if (file.existsSync()) await file.delete();

      final totalBytes = audio.size.totalBytes;
      onProgress?.call(
        AudioImportProgress(
          stage: AudioImportStage.downloading,
          title: video.title.trim(),
          totalBytes: totalBytes,
        ),
      );

      final sink = file.openWrite();
      var received = 0;
      try {
        await for (final chunk in _client.videos.streamsClient.get(audio)) {
          sink.add(chunk);
          received += chunk.length;
          onProgress?.call(
            AudioImportProgress(
              stage: AudioImportStage.downloading,
              title: video.title.trim(),
              receivedBytes: received,
              totalBytes: totalBytes,
            ),
          );
        }
      } finally {
        await sink.flush();
        await sink.close();
      }

      if (!file.existsSync() || file.lengthSync() == 0) {
        throw StateError('YouTube download produced no audio at $outputPath');
      }

      return YoutubeAudioImport(path: outputPath, title: video.title.trim());
    } on Object catch (error) {
      throw StateError(_friendlyYoutubeError(error));
    }
  }

  void close() => _client.close();

  AudioOnlyStreamInfo _pickAudioStream(StreamManifest manifest) {
    final mp4 = manifest.audioOnly
        .where((s) => s.container == StreamContainer.mp4);
    if (mp4.isEmpty) {
      throw StateError(
        'This video has no M4A audio stream Airo Mind can transcribe. '
        'Try a direct audio file URL instead.',
      );
    }
    return mp4.withHighestBitrate();
  }

  static String _friendlyYoutubeError(Object error) {
    final message = error.toString();
    if (message.contains('403')) {
      return 'YouTube blocked the audio download. Try again in a few minutes, '
          'or paste a direct audio file URL instead.';
    }
    if (message.contains('VideoUnavailable') ||
        message.contains('unplayable')) {
      return 'This YouTube video cannot be downloaded for transcription.';
    }
    if (message.contains('HttpClientClosedException')) {
      return 'YouTube download was interrupted before it finished.';
    }
    return message;
  }
}

/// Extracts a YouTube video id from common watch / shorts / youtu.be URLs.
String? extractYoutubeVideoId(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null || !uri.hasScheme) return null;
  final host = uri.host.toLowerCase();
  if (host == 'youtu.be' && uri.pathSegments.isNotEmpty) {
    return uri.pathSegments.first.split('?').first;
  }
  if (!host.contains('youtube')) return null;
  final fromQuery = uri.queryParameters['v'];
  if (fromQuery != null && fromQuery.isNotEmpty) return fromQuery;
  final shortsIndex = uri.pathSegments.indexOf('shorts');
  if (shortsIndex >= 0 && shortsIndex + 1 < uri.pathSegments.length) {
    return uri.pathSegments[shortsIndex + 1];
  }
  return null;
}
