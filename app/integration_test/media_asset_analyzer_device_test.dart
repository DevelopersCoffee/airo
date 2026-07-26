import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:platform_media/platform_media.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const fixturePath = String.fromEnvironment('AIRO_MEDIA_ANALYZER_FIXTURE');
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
}
