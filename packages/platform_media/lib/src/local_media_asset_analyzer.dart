import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import 'media_asset_profile_codec.dart';
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
  static int _nextAnalysisId = 1;

  final MethodChannel _channel;

  @override
  Future<MediaAssetAnalysisResult> analyze(
    MediaAssetAnalysisRequest request,
  ) async {
    final cancellation = request.cancellationToken;
    if (cancellation?.isCancelled ?? false) return _cancelledResult();
    final analysisId = 'analysis-${_nextAnalysisId++}';
    try {
      final invocation = _channel.invokeMapMethod<String, Object?>('analyze', {
        'analysisId': analysisId,
        'assetId': request.assetId,
        'filePath': request.filePath,
        'fileName': request.fileName,
        'fileSizeBytesHint': request.fileSizeBytesHint,
        'mimeTypeHint': request.mimeTypeHint,
      });
      final raw = cancellation == null
          ? await invocation
          : await Future.any<Map<String, Object?>?>([
              invocation,
              cancellation.whenCancelled.then((_) async {
                await _channel.invokeMethod<void>('cancel', {
                  'analysisId': analysisId,
                });
                return <String, Object?>{
                  'status': MediaAssetAnalysisStatus.cancelled.stableId,
                  'diagnostics': <String, Object?>{
                    'elapsedMs': 0,
                    'didUseMetadataProbe': true,
                  },
                };
              }),
            ]);
      if (raw == null) {
        return _unsupportedResult();
      }
      try {
        return _parseResult(raw);
      } on UnsupportedMediaAssetProfileVersion {
        return const MediaAssetAnalysisResult(
          status: MediaAssetAnalysisStatus.unsupportedInspection,
          failureReason: 'unsupported_profile_version',
          diagnostics: MediaAssetAnalysisDiagnostics(
            elapsed: Duration.zero,
            didUseMetadataProbe: false,
          ),
        );
      }
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

  MediaAssetAnalysisResult _cancelledResult() {
    return const MediaAssetAnalysisResult(
      status: MediaAssetAnalysisStatus.cancelled,
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
      peakMemoryBytes: (raw['peakMemoryBytes'] as num?)?.round(),
    );
  }

  MediaAssetProfile? _parseProfile(Map<Object?, Object?>? raw) {
    if (raw == null) return null;
    return MediaAssetProfileCodec.decode(raw);
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
    if (request.cancellationToken?.isCancelled ?? false) {
      return _cancelledResult(startedAt, didUseMetadataProbe: false);
    }
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
      if (request.cancellationToken?.isCancelled ?? false) {
        return _cancelledResult(startedAt, didUseMetadataProbe: true);
      }
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

  MediaAssetAnalysisResult _cancelledResult(
    DateTime startedAt, {
    required bool didUseMetadataProbe,
  }) {
    return MediaAssetAnalysisResult(
      status: MediaAssetAnalysisStatus.cancelled,
      diagnostics: MediaAssetAnalysisDiagnostics(
        elapsed: DateTime.now().difference(startedAt),
        didUseMetadataProbe: didUseMetadataProbe,
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
