import 'dart:async';

import 'package:equatable/equatable.dart';

const String kMediaAssetProfileSchemaVersion = '1.0.0';

enum MediaAssetContainer {
  mp4('mp4'),
  m4v('m4v'),
  mkv('mkv'),
  webm('webm'),
  avi('avi'),
  mov('mov'),
  ts('ts'),
  m2ts('m2ts'),
  flv('flv'),
  wmv('wmv'),
  vob('vob'),
  unknown('unknown');

  const MediaAssetContainer(this.stableId);

  final String stableId;

  static MediaAssetContainer fromExtension(String? extension) {
    return switch ((extension ?? '').toLowerCase()) {
      'mp4' => MediaAssetContainer.mp4,
      'm4v' => MediaAssetContainer.m4v,
      'mkv' => MediaAssetContainer.mkv,
      'webm' => MediaAssetContainer.webm,
      'avi' => MediaAssetContainer.avi,
      'mov' => MediaAssetContainer.mov,
      'ts' => MediaAssetContainer.ts,
      'm2ts' => MediaAssetContainer.m2ts,
      'flv' => MediaAssetContainer.flv,
      'wmv' => MediaAssetContainer.wmv,
      'vob' => MediaAssetContainer.vob,
      _ => MediaAssetContainer.unknown,
    };
  }

  static MediaAssetContainer fromMimeType(String? mimeType) {
    final normalized = (mimeType ?? '').toLowerCase();
    if (normalized.contains('matroska') || normalized.contains('x-mkv')) {
      return MediaAssetContainer.mkv;
    }
    if (normalized.contains('webm')) return MediaAssetContainer.webm;
    if (normalized.contains('mp4')) return MediaAssetContainer.mp4;
    if (normalized.contains('quicktime')) return MediaAssetContainer.mov;
    if (normalized.contains('mpegts') || normalized.contains('mp2t')) {
      return MediaAssetContainer.ts;
    }
    if (normalized.contains('x-msvideo')) return MediaAssetContainer.avi;
    if (normalized.contains('x-ms-wmv')) return MediaAssetContainer.wmv;
    if (normalized.contains('x-flv')) return MediaAssetContainer.flv;
    return MediaAssetContainer.unknown;
  }
}

enum MediaTrackConfidence {
  exact('exact'),
  inferred('inferred'),
  unknown('unknown');

  const MediaTrackConfidence(this.stableId);

  final String stableId;
}

enum MediaVideoCodec {
  h264('h264'),
  hevc('hevc'),
  av1('av1'),
  vp9('vp9'),
  unknown('unknown');

  const MediaVideoCodec(this.stableId);

  final String stableId;
}

enum MediaAudioCodec {
  aac('aac'),
  ac3('ac3'),
  eac3('eac3'),
  dts('dts'),
  trueHd('truehd'),
  opus('opus'),
  mp3('mp3'),
  unknown('unknown');

  const MediaAudioCodec(this.stableId);

  final String stableId;
}

enum MediaSubtitleFormat {
  srt('srt'),
  ass('ass'),
  pgs('pgs'),
  vobSub('vobsub'),
  dvb('dvb'),
  unknown('unknown');

  const MediaSubtitleFormat(this.stableId);

  final String stableId;
}

enum MediaDynamicRangeProfile {
  sdr('sdr'),
  hdr10('hdr10'),
  hdr10Plus('hdr10_plus'),
  dolbyVision('dolby_vision'),
  hlg('hlg'),
  unknown('unknown');

  const MediaDynamicRangeProfile(this.stableId);

  final String stableId;
}

enum MediaAssetWarningCode {
  containerInferredFromFileExtension('container_inferred_from_file_extension'),
  fileSizeUnavailable('file_size_unavailable'),
  durationUnavailable('duration_unavailable'),
  overallBitrateUnavailable('overall_bitrate_unavailable'),
  overallBitrateEstimated('overall_bitrate_estimated'),
  videoCodecUnavailable('video_codec_unavailable'),
  audioTracksUnavailable('audio_tracks_unavailable'),
  subtitleTracksUnavailable('subtitle_tracks_unavailable'),
  hdrUnavailable('hdr_unavailable'),
  metadataProbeFailed('metadata_probe_failed');

  const MediaAssetWarningCode(this.stableId);

  final String stableId;
}

enum MediaAssetAnalysisStatus {
  complete('complete'),
  partial('partial'),
  cancelled('cancelled'),
  permissionLost('permission_lost'),
  malformed('malformed'),
  unsupportedInspection('unsupported_inspection'),
  inspectionFailed('inspection_failed');

  const MediaAssetAnalysisStatus(this.stableId);

  final String stableId;
}

class MediaAssetDimensions extends Equatable {
  const MediaAssetDimensions({required this.width, required this.height})
    : assert(width >= 0),
      assert(height >= 0);

  final int width;
  final int height;

  bool get isKnown => width > 0 && height > 0;

  @override
  List<Object?> get props => [width, height];
}

class MediaVideoTrackProfile extends Equatable {
  const MediaVideoTrackProfile({
    required this.id,
    required this.codec,
    required this.dimensions,
    required this.confidence,
    this.bitrate,
    this.dynamicRange = MediaDynamicRangeProfile.unknown,
  });

  final String id;
  final MediaVideoCodec codec;
  final MediaAssetDimensions dimensions;
  final int? bitrate;
  final MediaDynamicRangeProfile dynamicRange;
  final MediaTrackConfidence confidence;

  @override
  List<Object?> get props => [
    id,
    codec,
    dimensions,
    bitrate,
    dynamicRange,
    confidence,
  ];
}

class MediaAudioTrackProfile extends Equatable {
  const MediaAudioTrackProfile({
    required this.id,
    required this.codec,
    required this.confidence,
    this.language,
    this.label,
    this.channelCount,
    this.isDefault = false,
    this.isCommentary = false,
  });

  final String id;
  final MediaAudioCodec codec;
  final MediaTrackConfidence confidence;
  final String? language;
  final String? label;
  final int? channelCount;
  final bool isDefault;
  final bool isCommentary;

  @override
  List<Object?> get props => [
    id,
    codec,
    confidence,
    language,
    label,
    channelCount,
    isDefault,
    isCommentary,
  ];
}

class MediaSubtitleTrackProfile extends Equatable {
  const MediaSubtitleTrackProfile({
    required this.id,
    required this.format,
    required this.confidence,
    this.language,
    this.label,
    this.isDefault = false,
    this.isForced = false,
    this.isCommentary = false,
  });

  final String id;
  final MediaSubtitleFormat format;
  final MediaTrackConfidence confidence;
  final String? language;
  final String? label;
  final bool isDefault;
  final bool isForced;
  final bool isCommentary;

  @override
  List<Object?> get props => [
    id,
    format,
    confidence,
    language,
    label,
    isDefault,
    isForced,
    isCommentary,
  ];
}

class MediaAssetProfile extends Equatable {
  const MediaAssetProfile({
    required this.assetId,
    required this.container,
    required this.videoTracks,
    required this.audioTracks,
    required this.subtitleTracks,
    required this.warnings,
    this.schemaVersion = kMediaAssetProfileSchemaVersion,
    this.duration,
    this.fileSizeBytes,
    this.overallBitrate,
  });

  final String schemaVersion;
  final String assetId;
  final MediaAssetContainer container;
  final Duration? duration;
  final int? fileSizeBytes;
  final int? overallBitrate;
  final List<MediaVideoTrackProfile> videoTracks;
  final List<MediaAudioTrackProfile> audioTracks;
  final List<MediaSubtitleTrackProfile> subtitleTracks;
  final List<MediaAssetWarningCode> warnings;

  @override
  List<Object?> get props => [
    schemaVersion,
    assetId,
    container,
    duration,
    fileSizeBytes,
    overallBitrate,
    videoTracks,
    audioTracks,
    subtitleTracks,
    warnings,
  ];
}

class MediaAssetAnalysisDiagnostics extends Equatable {
  const MediaAssetAnalysisDiagnostics({
    required this.elapsed,
    required this.didUseMetadataProbe,
    this.fileSizeBytes,
    this.estimatedBytesRead,
    this.peakMemoryBytes,
  });

  final Duration elapsed;
  final bool didUseMetadataProbe;
  final int? fileSizeBytes;
  final int? estimatedBytesRead;
  final int? peakMemoryBytes;

  @override
  List<Object?> get props => [
    elapsed,
    didUseMetadataProbe,
    fileSizeBytes,
    estimatedBytesRead,
    peakMemoryBytes,
  ];
}

class MediaAssetAnalysisRequest extends Equatable {
  const MediaAssetAnalysisRequest({
    required this.assetId,
    required this.filePath,
    this.fileName,
    this.fileSizeBytesHint,
    this.mimeTypeHint,
    this.cancellationToken,
  });

  final String assetId;
  final String filePath;
  final String? fileName;
  final int? fileSizeBytesHint;
  final String? mimeTypeHint;
  final MediaAssetAnalysisCancellationToken? cancellationToken;

  String get fileExtension {
    final name = fileName;
    if (name == null) return '';
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return '';
    return name.substring(dot + 1).toLowerCase();
  }

  @override
  String toString() {
    return 'MediaAssetAnalysisRequest('
        'assetId: $assetId, '
        'fileName: $fileName, '
        'fileSizeBytesHint: $fileSizeBytesHint, '
        'mimeTypeHint: $mimeTypeHint'
        ')';
  }

  @override
  List<Object?> get props => [
    assetId,
    filePath,
    fileName,
    fileSizeBytesHint,
    mimeTypeHint,
  ];
}

/// Cooperative cancellation shared by Dart and native media inspectors.
class MediaAssetAnalysisCancellationToken {
  final Completer<void> _cancelled = Completer<void>();

  bool get isCancelled => _cancelled.isCompleted;
  Future<void> get whenCancelled => _cancelled.future;

  void cancel() {
    if (!_cancelled.isCompleted) _cancelled.complete();
  }
}

class MediaAssetAnalysisResult extends Equatable {
  const MediaAssetAnalysisResult({
    required this.status,
    required this.diagnostics,
    this.profile,
    this.failureReason,
  });

  final MediaAssetAnalysisStatus status;
  final MediaAssetProfile? profile;
  final MediaAssetAnalysisDiagnostics diagnostics;
  final String? failureReason;

  bool get isSuccess =>
      status == MediaAssetAnalysisStatus.complete ||
      status == MediaAssetAnalysisStatus.partial;

  @override
  String toString() {
    return 'MediaAssetAnalysisResult('
        'status: ${status.stableId}, '
        'assetId: ${profile?.assetId}, '
        'warnings: ${profile?.warnings.map((warning) => warning.stableId).toList()}, '
        'failureReason: $failureReason'
        ')';
  }

  @override
  List<Object?> get props => [status, profile, diagnostics, failureReason];
}
