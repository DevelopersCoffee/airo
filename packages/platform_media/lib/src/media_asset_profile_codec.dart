import 'media_asset_profile_models.dart';

/// Stable wire codec for the platform-neutral media inspection contract.
abstract final class MediaAssetProfileCodec {
  static Map<String, Object?> encode(MediaAssetProfile profile) {
    return <String, Object?>{
      'schemaVersion': profile.schemaVersion,
      'assetId': profile.assetId,
      'container': profile.container.stableId,
      'durationMs': profile.duration?.inMilliseconds,
      'fileSizeBytes': profile.fileSizeBytes,
      'overallBitrate': profile.overallBitrate,
      'videoTracks': [
        for (final track in profile.videoTracks)
          <String, Object?>{
            'id': track.id,
            'codec': track.codec.stableId,
            'width': track.dimensions.width,
            'height': track.dimensions.height,
            'bitrate': track.bitrate,
            'dynamicRange': track.dynamicRange.stableId,
            'confidence': track.confidence.stableId,
          },
      ],
      'audioTracks': [
        for (final track in profile.audioTracks)
          <String, Object?>{
            'id': track.id,
            'codec': track.codec.stableId,
            'confidence': track.confidence.stableId,
            'language': track.language,
            'label': track.label,
            'channelCount': track.channelCount,
            'isDefault': track.isDefault,
            'isCommentary': track.isCommentary,
          },
      ],
      'subtitleTracks': [
        for (final track in profile.subtitleTracks)
          <String, Object?>{
            'id': track.id,
            'format': track.format.stableId,
            'confidence': track.confidence.stableId,
            'language': track.language,
            'label': track.label,
            'isDefault': track.isDefault,
            'isForced': track.isForced,
            'isCommentary': track.isCommentary,
          },
      ],
      'warnings': [for (final warning in profile.warnings) warning.stableId],
    };
  }

  static MediaAssetProfile decode(Map<Object?, Object?> raw) {
    final schemaVersion =
        raw['schemaVersion'] as String? ?? kMediaAssetProfileSchemaVersion;
    if (schemaVersion != kMediaAssetProfileSchemaVersion) {
      throw UnsupportedMediaAssetProfileVersion(
        receivedVersion: schemaVersion,
        supportedVersion: kMediaAssetProfileSchemaVersion,
      );
    }
    return MediaAssetProfile(
      schemaVersion: schemaVersion,
      assetId: raw['assetId'] as String? ?? 'unknown',
      container: _enumByStableId(
        MediaAssetContainer.values,
        raw['container'] as String?,
        MediaAssetContainer.unknown,
      ),
      duration: _durationFromMs(raw['durationMs']),
      fileSizeBytes: (raw['fileSizeBytes'] as num?)?.round(),
      overallBitrate: (raw['overallBitrate'] as num?)?.round(),
      videoTracks: _decodeVideoTracks(raw['videoTracks']),
      audioTracks: _decodeAudioTracks(raw['audioTracks']),
      subtitleTracks: _decodeSubtitleTracks(raw['subtitleTracks']),
      warnings: _decodeWarnings(raw['warnings']),
    );
  }

  static List<MediaVideoTrackProfile> _decodeVideoTracks(Object? rawTracks) {
    return _maps(rawTracks)
        .map(
          (raw) => MediaVideoTrackProfile(
            id: raw['id'] as String? ?? 'video-unknown',
            codec: _enumByStableId(
              MediaVideoCodec.values,
              raw['codec'] as String?,
              MediaVideoCodec.unknown,
            ),
            dimensions: MediaAssetDimensions(
              width: (raw['width'] as num?)?.round() ?? 0,
              height: (raw['height'] as num?)?.round() ?? 0,
            ),
            bitrate: (raw['bitrate'] as num?)?.round(),
            dynamicRange: _enumByStableId(
              MediaDynamicRangeProfile.values,
              raw['dynamicRange'] as String?,
              MediaDynamicRangeProfile.unknown,
            ),
            confidence: _enumByStableId(
              MediaTrackConfidence.values,
              raw['confidence'] as String?,
              MediaTrackConfidence.unknown,
            ),
          ),
        )
        .toList(growable: false);
  }

  static List<MediaAudioTrackProfile> _decodeAudioTracks(Object? rawTracks) {
    return _maps(rawTracks)
        .map(
          (raw) => MediaAudioTrackProfile(
            id: raw['id'] as String? ?? 'audio-unknown',
            codec: _enumByStableId(
              MediaAudioCodec.values,
              raw['codec'] as String?,
              MediaAudioCodec.unknown,
            ),
            confidence: _enumByStableId(
              MediaTrackConfidence.values,
              raw['confidence'] as String?,
              MediaTrackConfidence.unknown,
            ),
            language: raw['language'] as String?,
            label: raw['label'] as String?,
            channelCount: (raw['channelCount'] as num?)?.round(),
            isDefault: raw['isDefault'] as bool? ?? false,
            isCommentary: raw['isCommentary'] as bool? ?? false,
          ),
        )
        .toList(growable: false);
  }

  static List<MediaSubtitleTrackProfile> _decodeSubtitleTracks(
    Object? rawTracks,
  ) {
    return _maps(rawTracks)
        .map(
          (raw) => MediaSubtitleTrackProfile(
            id: raw['id'] as String? ?? 'subtitle-unknown',
            format: _enumByStableId(
              MediaSubtitleFormat.values,
              raw['format'] as String?,
              MediaSubtitleFormat.unknown,
            ),
            confidence: _enumByStableId(
              MediaTrackConfidence.values,
              raw['confidence'] as String?,
              MediaTrackConfidence.unknown,
            ),
            language: raw['language'] as String?,
            label: raw['label'] as String?,
            isDefault: raw['isDefault'] as bool? ?? false,
            isForced: raw['isForced'] as bool? ?? false,
            isCommentary: raw['isCommentary'] as bool? ?? false,
          ),
        )
        .toList(growable: false);
  }

  static List<MediaAssetWarningCode> _decodeWarnings(Object? rawWarnings) {
    return (rawWarnings as List<Object?>? ?? const [])
        .whereType<String>()
        .map(
          (value) => _enumByStableId(
            MediaAssetWarningCode.values,
            value,
            MediaAssetWarningCode.metadataProbeFailed,
          ),
        )
        .toList(growable: false);
  }

  static Iterable<Map<Object?, Object?>> _maps(Object? raw) {
    return (raw as List<Object?>? ?? const [])
        .whereType<Map<Object?, Object?>>();
  }

  static Duration? _durationFromMs(Object? raw) {
    final milliseconds = (raw as num?)?.round();
    if (milliseconds == null || milliseconds <= 0) return null;
    return Duration(milliseconds: milliseconds);
  }

  static T _enumByStableId<T>(
    Iterable<T> values,
    String? stableId,
    T fallback,
  ) {
    for (final value in values) {
      if ((value as dynamic).stableId == stableId) return value;
    }
    return fallback;
  }
}

class UnsupportedMediaAssetProfileVersion implements Exception {
  const UnsupportedMediaAssetProfileVersion({
    required this.receivedVersion,
    required this.supportedVersion,
  });

  final String receivedVersion;
  final String supportedVersion;

  @override
  String toString() {
    return 'UnsupportedMediaAssetProfileVersion('
        'receivedVersion: $receivedVersion, '
        'supportedVersion: $supportedVersion'
        ')';
  }
}
