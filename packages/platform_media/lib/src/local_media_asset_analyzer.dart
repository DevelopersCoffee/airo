import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import 'media_asset_profile_models.dart';

abstract class LocalMediaAssetAnalyzer {
  Future<MediaAssetAnalysisResult> analyze(MediaAssetAnalysisRequest request);
}

class DefaultLocalMediaAssetAnalyzer implements LocalMediaAssetAnalyzer {
  DefaultLocalMediaAssetAnalyzer({
    LocalMediaAssetAnalyzer? nativeAnalyzer,
    LocalMediaAssetAnalyzer? fallbackAnalyzer,
  }) : _nativeAnalyzer = nativeAnalyzer ?? HostPlatformMediaAssetAnalyzer(),
       _fallbackAnalyzer =
           fallbackAnalyzer ?? const VideoPlayerLocalMediaAssetAnalyzer();

  final LocalMediaAssetAnalyzer _nativeAnalyzer;
  final LocalMediaAssetAnalyzer _fallbackAnalyzer;

  @override
  Future<MediaAssetAnalysisResult> analyze(
    MediaAssetAnalysisRequest request,
  ) async {
    final nativeResult = await _nativeAnalyzer.analyze(request);
    if (nativeResult.status != MediaAssetAnalysisStatus.unsupportedInspection) {
      return nativeResult;
    }
    return _fallbackAnalyzer.analyze(request);
  }
}

class HostPlatformMediaAssetAnalyzer implements LocalMediaAssetAnalyzer {
  HostPlatformMediaAssetAnalyzer({MethodChannel? channel})
    : _channel = channel ?? _defaultChannel;

  static MethodChannel _defaultChannel = const MethodChannel(
    'com.airo.media_asset_analyzer',
  );

  final MethodChannel _channel;

  @override
  Future<MediaAssetAnalysisResult> analyze(
    MediaAssetAnalysisRequest request,
  ) async {
    try {
      final raw = await _channel.invokeMapMethod<String, Object?>('analyze', {
        'assetId': request.assetId,
        'filePath': request.filePath,
        'fileName': request.fileName,
        'fileSizeBytesHint': request.fileSizeBytesHint,
        'mimeTypeHint': request.mimeTypeHint,
      });
      if (raw == null) {
        return _unsupportedResult();
      }
      return _parseResult(raw);
    } on MissingPluginException {
      return _unsupportedResult();
    } on PlatformException catch (error) {
      return MediaAssetAnalysisResult(
        status: MediaAssetAnalysisStatus.inspectionFailed,
        failureReason: error.code,
        diagnostics: const MediaAssetAnalysisDiagnostics(
          elapsed: Duration.zero,
          didUseMetadataProbe: false,
        ),
      );
    }
  }

  MediaAssetAnalysisResult _unsupportedResult() {
    return const MediaAssetAnalysisResult(
      status: MediaAssetAnalysisStatus.unsupportedInspection,
      diagnostics: MediaAssetAnalysisDiagnostics(
        elapsed: Duration.zero,
        didUseMetadataProbe: false,
      ),
    );
  }

  MediaAssetAnalysisResult _parseResult(Map<String, Object?> raw) {
    return MediaAssetAnalysisResult(
      status: _analysisStatusFromStableId(raw['status'] as String?),
      failureReason: raw['failureReason'] as String?,
      diagnostics: _parseDiagnostics(
        raw['diagnostics'] as Map<Object?, Object?>? ?? const {},
      ),
      profile: _parseProfile(raw['profile'] as Map<Object?, Object?>?),
    );
  }

  MediaAssetAnalysisDiagnostics _parseDiagnostics(Map<Object?, Object?> raw) {
    return MediaAssetAnalysisDiagnostics(
      elapsed: Duration(milliseconds: (raw['elapsedMs'] as num?)?.round() ?? 0),
      didUseMetadataProbe: raw['didUseMetadataProbe'] as bool? ?? false,
      fileSizeBytes: (raw['fileSizeBytes'] as num?)?.round(),
      estimatedBytesRead: (raw['estimatedBytesRead'] as num?)?.round(),
    );
  }

  MediaAssetProfile? _parseProfile(Map<Object?, Object?>? raw) {
    if (raw == null) return null;
    return MediaAssetProfile(
      schemaVersion:
          raw['schemaVersion'] as String? ?? kMediaAssetProfileSchemaVersion,
      assetId: raw['assetId'] as String? ?? 'unknown',
      container: _containerFromStableId(raw['container'] as String?),
      duration: _durationFromMs(raw['durationMs']),
      fileSizeBytes: (raw['fileSizeBytes'] as num?)?.round(),
      overallBitrate: (raw['overallBitrate'] as num?)?.round(),
      videoTracks: _parseVideoTracks(raw['videoTracks']),
      audioTracks: _parseAudioTracks(raw['audioTracks']),
      subtitleTracks: _parseSubtitleTracks(raw['subtitleTracks']),
      warnings: _parseWarnings(raw['warnings']),
    );
  }

  List<MediaVideoTrackProfile> _parseVideoTracks(Object? rawTracks) {
    final tracks = rawTracks as List<Object?>? ?? const [];
    return tracks
        .whereType<Map<Object?, Object?>>()
        .map(
          (raw) => MediaVideoTrackProfile(
            id: raw['id'] as String? ?? 'video-unknown',
            codec: _videoCodecFromStableId(raw['codec'] as String?),
            bitrate: (raw['bitrate'] as num?)?.round(),
            dynamicRange: _dynamicRangeFromStableId(
              raw['dynamicRange'] as String?,
            ),
            confidence: _confidenceFromStableId(raw['confidence'] as String?),
            dimensions: MediaAssetDimensions(
              width: (raw['width'] as num?)?.round() ?? 0,
              height: (raw['height'] as num?)?.round() ?? 0,
            ),
          ),
        )
        .toList(growable: false);
  }

  List<MediaAudioTrackProfile> _parseAudioTracks(Object? rawTracks) {
    final tracks = rawTracks as List<Object?>? ?? const [];
    return tracks
        .whereType<Map<Object?, Object?>>()
        .map(
          (raw) => MediaAudioTrackProfile(
            id: raw['id'] as String? ?? 'audio-unknown',
            codec: _audioCodecFromStableId(raw['codec'] as String?),
            confidence: _confidenceFromStableId(raw['confidence'] as String?),
            language: raw['language'] as String?,
            label: raw['label'] as String?,
            channelCount: (raw['channelCount'] as num?)?.round(),
            isDefault: raw['isDefault'] as bool? ?? false,
            isCommentary: raw['isCommentary'] as bool? ?? false,
          ),
        )
        .toList(growable: false);
  }

  List<MediaSubtitleTrackProfile> _parseSubtitleTracks(Object? rawTracks) {
    final tracks = rawTracks as List<Object?>? ?? const [];
    return tracks
        .whereType<Map<Object?, Object?>>()
        .map(
          (raw) => MediaSubtitleTrackProfile(
            id: raw['id'] as String? ?? 'subtitle-unknown',
            format: _subtitleFormatFromStableId(raw['format'] as String?),
            confidence: _confidenceFromStableId(raw['confidence'] as String?),
            language: raw['language'] as String?,
            label: raw['label'] as String?,
            isDefault: raw['isDefault'] as bool? ?? false,
            isForced: raw['isForced'] as bool? ?? false,
            isCommentary: raw['isCommentary'] as bool? ?? false,
          ),
        )
        .toList(growable: false);
  }

  List<MediaAssetWarningCode> _parseWarnings(Object? rawWarnings) {
    final warnings = rawWarnings as List<Object?>? ?? const [];
    return warnings
        .whereType<String>()
        .map(_warningCodeFromStableId)
        .toList(growable: false);
  }

  Duration? _durationFromMs(Object? raw) {
    final milliseconds = (raw as num?)?.round();
    if (milliseconds == null || milliseconds <= 0) return null;
    return Duration(milliseconds: milliseconds);
  }

  @visibleForTesting
  static void debugSetMethodChannel(MethodChannel channel) {
    _defaultChannel = channel;
  }
}

class VideoPlayerLocalMediaAssetAnalyzer implements LocalMediaAssetAnalyzer {
  const VideoPlayerLocalMediaAssetAnalyzer();

  @override
  Future<MediaAssetAnalysisResult> analyze(
    MediaAssetAnalysisRequest request,
  ) async {
    final startedAt = DateTime.now();
    final warnings = <MediaAssetWarningCode>[];
    final container = _resolveContainer(request, warnings);

    int? fileSizeBytes = request.fileSizeBytesHint;
    if (fileSizeBytes == null) {
      try {
        fileSizeBytes = await File(request.filePath).length();
      } catch (_) {
        warnings.add(MediaAssetWarningCode.fileSizeUnavailable);
      }
    }

    Duration? duration;
    MediaAssetDimensions dimensions = const MediaAssetDimensions(
      width: 0,
      height: 0,
    );
    var didUseMetadataProbe = false;
    String? failureReason;

    final controller = VideoPlayerController.file(File(request.filePath));
    try {
      didUseMetadataProbe = true;
      await controller.initialize();
      duration = controller.value.duration;
      final size = controller.value.size;
      dimensions = MediaAssetDimensions(
        width: size.width.round(),
        height: size.height.round(),
      );
    } catch (_) {
      warnings.add(MediaAssetWarningCode.metadataProbeFailed);
      failureReason = 'metadata_probe_failed';
    } finally {
      await controller.dispose();
    }

    if (duration == null || duration == Duration.zero) {
      warnings.add(MediaAssetWarningCode.durationUnavailable);
      duration = null;
    }
    final overallBitrate = duration != null && fileSizeBytes != null
        ? _estimatedBitrateBitsPerSecond(
            fileSizeBytes: fileSizeBytes,
            duration: duration,
          )
        : null;
    if (overallBitrate == null) {
      warnings.add(MediaAssetWarningCode.overallBitrateUnavailable);
    } else {
      warnings.add(MediaAssetWarningCode.overallBitrateEstimated);
    }
    warnings.add(MediaAssetWarningCode.videoCodecUnavailable);
    warnings.add(MediaAssetWarningCode.audioTracksUnavailable);
    warnings.add(MediaAssetWarningCode.subtitleTracksUnavailable);
    warnings.add(MediaAssetWarningCode.hdrUnavailable);

    final profile = MediaAssetProfile(
      assetId: request.assetId,
      container: container,
      duration: duration,
      fileSizeBytes: fileSizeBytes,
      overallBitrate: overallBitrate,
      videoTracks: [
        MediaVideoTrackProfile(
          id: 'video-0',
          codec: MediaVideoCodec.unknown,
          dimensions: dimensions,
          dynamicRange: MediaDynamicRangeProfile.unknown,
          confidence: dimensions.isKnown
              ? MediaTrackConfidence.inferred
              : MediaTrackConfidence.unknown,
        ),
      ],
      audioTracks: const [],
      subtitleTracks: const [],
      warnings: warnings.toSet().toList(growable: false),
    );

    final status = switch (failureReason) {
      null => MediaAssetAnalysisStatus.partial,
      _ => MediaAssetAnalysisStatus.inspectionFailed,
    };

    return MediaAssetAnalysisResult(
      status: status,
      profile: profile,
      failureReason: failureReason,
      diagnostics: MediaAssetAnalysisDiagnostics(
        elapsed: DateTime.now().difference(startedAt),
        didUseMetadataProbe: didUseMetadataProbe,
        fileSizeBytes: fileSizeBytes,
        estimatedBytesRead: null,
      ),
    );
  }

  MediaAssetContainer _resolveContainer(
    MediaAssetAnalysisRequest request,
    List<MediaAssetWarningCode> warnings,
  ) {
    final fromMime = MediaAssetContainer.fromMimeType(request.mimeTypeHint);
    if (fromMime != MediaAssetContainer.unknown) return fromMime;
    final fromExtension = MediaAssetContainer.fromExtension(
      request.fileExtension,
    );
    if (fromExtension != MediaAssetContainer.unknown) {
      warnings.add(MediaAssetWarningCode.containerInferredFromFileExtension);
    }
    return fromExtension;
  }

  int _estimatedBitrateBitsPerSecond({
    required int fileSizeBytes,
    required Duration duration,
  }) {
    final seconds = duration.inMilliseconds / 1000;
    if (seconds <= 0) return 0;
    return ((fileSizeBytes * 8) / seconds).round();
  }
}

MediaAssetAnalysisStatus _analysisStatusFromStableId(String? stableId) {
  return MediaAssetAnalysisStatus.values.firstWhere(
    (value) => value.stableId == stableId,
    orElse: () => MediaAssetAnalysisStatus.inspectionFailed,
  );
}

MediaAssetContainer _containerFromStableId(String? stableId) {
  return MediaAssetContainer.values.firstWhere(
    (value) => value.stableId == stableId,
    orElse: () => MediaAssetContainer.unknown,
  );
}

MediaTrackConfidence _confidenceFromStableId(String? stableId) {
  return MediaTrackConfidence.values.firstWhere(
    (value) => value.stableId == stableId,
    orElse: () => MediaTrackConfidence.unknown,
  );
}

MediaVideoCodec _videoCodecFromStableId(String? stableId) {
  return MediaVideoCodec.values.firstWhere(
    (value) => value.stableId == stableId,
    orElse: () => MediaVideoCodec.unknown,
  );
}

MediaAudioCodec _audioCodecFromStableId(String? stableId) {
  return MediaAudioCodec.values.firstWhere(
    (value) => value.stableId == stableId,
    orElse: () => MediaAudioCodec.unknown,
  );
}

MediaSubtitleFormat _subtitleFormatFromStableId(String? stableId) {
  return MediaSubtitleFormat.values.firstWhere(
    (value) => value.stableId == stableId,
    orElse: () => MediaSubtitleFormat.unknown,
  );
}

MediaDynamicRangeProfile _dynamicRangeFromStableId(String? stableId) {
  return MediaDynamicRangeProfile.values.firstWhere(
    (value) => value.stableId == stableId,
    orElse: () => MediaDynamicRangeProfile.unknown,
  );
}

MediaAssetWarningCode _warningCodeFromStableId(String? stableId) {
  return MediaAssetWarningCode.values.firstWhere(
    (value) => value.stableId == stableId,
    orElse: () => MediaAssetWarningCode.metadataProbeFailed,
  );
}
