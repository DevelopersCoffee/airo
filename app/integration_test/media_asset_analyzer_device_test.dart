import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:platform_media/platform_media.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const fixturePath = String.fromEnvironment('AIRO_MEDIA_ANALYZER_FIXTURE');
  const fixtureDirectory = String.fromEnvironment(
    'AIRO_MEDIA_ANALYZER_FIXTURE_DIRECTORY',
  );
  const imageSubtitleFixturePath = String.fromEnvironment(
    'AIRO_MEDIA_ANALYZER_IMAGE_SUBTITLE_FIXTURE',
  );
  const expectLargeFixture = bool.fromEnvironment(
    'AIRO_MEDIA_ANALYZER_EXPECT_LARGE',
  );

  testWidgets(
    'native adapter returns a normalized redacted profile',
    (_) async {
      final fixture = File(fixturePath);
      expect(fixture.existsSync(), isTrue);

      final result = await HostPlatformMediaAssetAnalyzer().analyze(
        MediaAssetAnalysisRequest(
          assetId: 'physical-device-fixture',
          filePath: fixture.path,
          fileName: fixture.uri.pathSegments.last,
          fileSizeBytesHint: fixture.lengthSync(),
        ),
      );

      expect(result.status, MediaAssetAnalysisStatus.complete);
      expect(result.profile?.videoTracks, isNotEmpty);
      expect(result.profile?.duration, isNotNull);
      expect(result.diagnostics.didUseMetadataProbe, isTrue);
      expect(result.toString(), isNot(contains(fixture.path)));
      if (expectLargeFixture) {
        expect(
          result.profile?.fileSizeBytes,
          greaterThan(5 * 1024 * 1024 * 1024),
        );
        expect(result.profile?.duration, greaterThan(const Duration(hours: 2)));
        expect(result.profile?.audioTracks, isNotEmpty);
        if (result.profile?.subtitleTracks.isEmpty ?? true) {
          expect(
            result.profile?.warnings,
            contains(MediaAssetWarningCode.subtitleTracksUnavailable),
          );
        }
      }

      debugPrint(
        'AIRO_MEDIA_ANALYZER_EVIDENCE ${jsonEncode({
          'status': result.status.stableId,
          'fileSizeBytes': result.profile?.fileSizeBytes,
          'durationMs': result.profile?.duration?.inMilliseconds,
          'container': result.profile?.container.stableId,
          'videoCodecs': [for (final track in result.profile?.videoTracks ?? const []) track.codec.stableId],
          'audioCodecs': [for (final track in result.profile?.audioTracks ?? const []) track.codec.stableId],
          'subtitleFormats': [for (final track in result.profile?.subtitleTracks ?? const []) track.format.stableId],
          'elapsedMs': result.diagnostics.elapsed.inMilliseconds,
          'estimatedBytesRead': result.diagnostics.estimatedBytesRead,
          'peakMemoryBytes': result.diagnostics.peakMemoryBytes,
        })}',
      );
    },
    skip: fixturePath.isEmpty,
  );

  testWidgets(
    'native adapter preserves deterministic fixture capabilities',
    (_) async {
      const fixtures = [
        (
          fileName: 'mp4-h264-aac.mp4',
          container: MediaAssetContainer.mp4,
          videoCodec: MediaVideoCodec.h264,
          audioCodecs: [MediaAudioCodec.aac],
          audioUnavailable: false,
          dynamicRange: MediaDynamicRangeProfile.unknown,
        ),
        (
          fileName: 'webm-vp9-opus.webm',
          container: MediaAssetContainer.webm,
          videoCodec: MediaVideoCodec.vp9,
          audioCodecs: [MediaAudioCodec.opus],
          audioUnavailable: false,
          dynamicRange: MediaDynamicRangeProfile.unknown,
        ),
        (
          fileName: 'mkv-hevc-main10-hdr10-dts.mkv',
          container: MediaAssetContainer.mkv,
          videoCodec: MediaVideoCodec.hevc,
          audioCodecs: <MediaAudioCodec>[],
          audioUnavailable: true,
          dynamicRange: MediaDynamicRangeProfile.hdr10,
        ),
        (
          fileName: 'mkv-multi-audio-text-subtitles.mkv',
          container: MediaAssetContainer.mkv,
          videoCodec: MediaVideoCodec.h264,
          audioCodecs: [MediaAudioCodec.aac, MediaAudioCodec.aac],
          audioUnavailable: false,
          dynamicRange: MediaDynamicRangeProfile.unknown,
        ),
      ];

      for (final expectation in fixtures) {
        final fixture = File('$fixtureDirectory/${expectation.fileName}');
        expect(fixture.existsSync(), isTrue, reason: expectation.fileName);

        final result = await HostPlatformMediaAssetAnalyzer().analyze(
          MediaAssetAnalysisRequest(
            assetId: 'deterministic-fixture',
            filePath: fixture.path,
            fileName: expectation.fileName,
            fileSizeBytesHint: fixture.lengthSync(),
          ),
        );
        final profile = result.profile;

        expect(
          result.status,
          MediaAssetAnalysisStatus.complete,
          reason: expectation.fileName,
        );
        expect(
          profile?.container,
          expectation.container,
          reason: expectation.fileName,
        );
        expect(
          profile?.videoTracks.single.codec,
          expectation.videoCodec,
          reason: expectation.fileName,
        );
        expect(
          [for (final track in profile?.audioTracks ?? const []) track.codec],
          expectation.audioCodecs,
          reason: expectation.fileName,
        );
        expect(
          profile?.warnings.contains(
            MediaAssetWarningCode.audioTracksUnavailable,
          ),
          expectation.audioUnavailable,
          reason: expectation.fileName,
        );
        expect(
          profile?.videoTracks.single.dynamicRange,
          expectation.dynamicRange,
          reason: expectation.fileName,
        );
        expect(
          result.toString(),
          isNot(contains(fixture.path)),
          reason: expectation.fileName,
        );

        debugPrint(
          'AIRO_MEDIA_ANALYZER_FIXTURE_EVIDENCE ${jsonEncode({
            'fixture': expectation.fileName,
            'status': result.status.stableId,
            'container': profile?.container.stableId,
            'videoCodecs': [for (final track in profile?.videoTracks ?? const []) track.codec.stableId],
            'audioCodecs': [for (final track in profile?.audioTracks ?? const []) track.codec.stableId],
            'subtitleFormats': [for (final track in profile?.subtitleTracks ?? const []) track.format.stableId],
            'dynamicRanges': [for (final track in profile?.videoTracks ?? const []) track.dynamicRange.stableId],
            'warnings': [for (final warning in profile?.warnings ?? const []) warning.stableId],
          })}',
        );
      }
    },
    skip: fixtureDirectory.isEmpty,
  );

  testWidgets(
    'native adapter exposes image subtitles or explicit uncertainty',
    (_) async {
      final fixture = File(imageSubtitleFixturePath);
      expect(fixture.existsSync(), isTrue);

      final result = await HostPlatformMediaAssetAnalyzer().analyze(
        MediaAssetAnalysisRequest(
          assetId: 'image-subtitle-fixture',
          filePath: fixture.path,
          fileName: 'image-subtitle.mkv',
          fileSizeBytesHint: fixture.lengthSync(),
        ),
      );
      final subtitleFormats = [
        for (final track in result.profile?.subtitleTracks ?? const [])
          track.format,
      ];

      expect(result.status, MediaAssetAnalysisStatus.complete);
      if (subtitleFormats.isEmpty) {
        expect(
          result.profile?.warnings,
          contains(MediaAssetWarningCode.subtitleTracksUnavailable),
        );
      } else {
        expect(subtitleFormats, contains(MediaSubtitleFormat.vobSub));
      }
      expect(result.toString(), isNot(contains(fixture.path)));
      debugPrint(
        'AIRO_MEDIA_ANALYZER_IMAGE_SUBTITLE_EVIDENCE ${jsonEncode({
          'status': result.status.stableId,
          'subtitleFormats': [for (final format in subtitleFormats) format.stableId],
          'warnings': [for (final warning in result.profile?.warnings ?? const []) warning.stableId],
        })}',
      );
    },
    skip: imageSubtitleFixturePath.isEmpty,
  );
}
