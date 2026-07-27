import 'package:flutter_test/flutter_test.dart';
import 'package:platform_media/platform_media.dart';

void main() {
  test('version 1 profile round-trips every normalized media dimension', () {
    const profile = MediaAssetProfile(
      assetId: 'asset-1',
      container: MediaAssetContainer.mkv,
      duration: Duration(hours: 2, minutes: 10, seconds: 7),
      fileSizeBytes: 6101307309,
      overallBitrate: 6250000,
      videoTracks: [
        MediaVideoTrackProfile(
          id: 'video-0',
          codec: MediaVideoCodec.hevc,
          dimensions: MediaAssetDimensions(width: 3840, height: 2160),
          bitrate: 5800000,
          dynamicRange: MediaDynamicRangeProfile.hdr10,
          confidence: MediaTrackConfidence.exact,
        ),
      ],
      audioTracks: [
        MediaAudioTrackProfile(
          id: 'audio-1',
          codec: MediaAudioCodec.dts,
          confidence: MediaTrackConfidence.exact,
          language: 'eng',
          label: 'Main',
          channelCount: 6,
          isDefault: true,
        ),
      ],
      subtitleTracks: [
        MediaSubtitleTrackProfile(
          id: 'subtitle-2',
          format: MediaSubtitleFormat.pgs,
          confidence: MediaTrackConfidence.exact,
          language: 'eng',
          label: 'Signs',
          isForced: true,
        ),
      ],
      warnings: [MediaAssetWarningCode.overallBitrateEstimated],
    );

    final encoded = MediaAssetProfileCodec.encode(profile);
    final decoded = MediaAssetProfileCodec.decode(encoded);

    expect(decoded, profile);
    expect(encoded['schemaVersion'], kMediaAssetProfileSchemaVersion);
    expect(encoded.toString(), isNot(contains('/')));
  });

  test('unknown profile schema fails closed with a typed version error', () {
    final encoded = <String, Object?>{
      'schemaVersion': '2.0.0',
      'assetId': 'asset-1',
      'container': 'mp4',
      'videoTracks': const [],
      'audioTracks': const [],
      'subtitleTracks': const [],
      'warnings': const [],
    };

    expect(
      () => MediaAssetProfileCodec.decode(encoded),
      throwsA(
        isA<UnsupportedMediaAssetProfileVersion>()
            .having(
              (error) => error.receivedVersion,
              'receivedVersion',
              '2.0.0',
            )
            .having(
              (error) => error.supportedVersion,
              'supportedVersion',
              kMediaAssetProfileSchemaVersion,
            ),
      ),
    );
  });
}
