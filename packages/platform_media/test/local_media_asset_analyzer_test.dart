import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_media/platform_media.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'support/fake_video_player_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late File mediaFile;
  late FakeVideoPlayerPlatform fakePlatform;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'local_media_asset_analyzer_test',
    );
    mediaFile = File('${tempDir.path}/movie.mkv');
    await mediaFile.writeAsBytes(List<int>.filled(2048, 7));
    fakePlatform = FakeVideoPlayerPlatform(
      fakeDuration: const Duration(minutes: 130, seconds: 7),
      fakeSize: const Size(3840, 2160),
    );
    VideoPlayerPlatform.instance = fakePlatform;
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  test('analyzes a local asset into a normalized partial profile', () async {
    const analyzer = VideoPlayerLocalMediaAssetAnalyzer();

    final result = await analyzer.analyze(
      MediaAssetAnalysisRequest(
        assetId: 'asset-1',
        filePath: mediaFile.path,
        fileName: 'movie.mkv',
        mimeTypeHint: 'video/x-matroska',
      ),
    );

    expect(result.status, MediaAssetAnalysisStatus.partial);
    expect(result.failureReason, isNull);
    expect(result.profile, isNotNull);
    expect(result.profile!.schemaVersion, kMediaAssetProfileSchemaVersion);
    expect(result.profile!.container, MediaAssetContainer.mkv);
    expect(result.profile!.duration, const Duration(minutes: 130, seconds: 7));
    expect(result.profile!.fileSizeBytes, 2048);
    expect(result.profile!.overallBitrate, isNotNull);
    expect(result.profile!.videoTracks, hasLength(1));
    expect(
      result.profile!.videoTracks.single.dimensions,
      const MediaAssetDimensions(width: 3840, height: 2160),
    );
    expect(
      result.profile!.warnings,
      contains(MediaAssetWarningCode.overallBitrateEstimated),
    );
    expect(
      result.profile!.warnings,
      contains(MediaAssetWarningCode.videoCodecUnavailable),
    );
    expect(result.diagnostics.didUseMetadataProbe, isTrue);
    expect(result.diagnostics.fileSizeBytes, 2048);
  });

  test(
    'surfaces metadata probe failure without exposing the file path',
    () async {
      fakePlatform.scriptedInitError = PlatformException(
        code: 'VideoError',
        message: 'decoder rejected format',
      );
      const analyzer = VideoPlayerLocalMediaAssetAnalyzer();

      final result = await analyzer.analyze(
        MediaAssetAnalysisRequest(
          assetId: 'asset-2',
          filePath: mediaFile.path,
          fileName: 'movie.mkv',
        ),
      );

      expect(result.status, MediaAssetAnalysisStatus.inspectionFailed);
      expect(result.failureReason, 'metadata_probe_failed');
      expect(
        result.profile!.warnings,
        contains(MediaAssetWarningCode.metadataProbeFailed),
      );
      expect(result.toString(), isNot(contains(mediaFile.path)));
    },
  );

  test('request redaction never prints the raw local path', () {
    final request = MediaAssetAnalysisRequest(
      assetId: 'asset-3',
      filePath: mediaFile.path,
      fileName: 'movie.mkv',
      fileSizeBytesHint: 1234,
      mimeTypeHint: 'video/x-matroska',
    );

    expect(request.toString(), contains('asset-3'));
    expect(request.toString(), contains('movie.mkv'));
    expect(request.toString(), isNot(contains(mediaFile.path)));
  });

  test('pre-cancelled fallback never opens the selected asset', () async {
    final cancellation = MediaAssetAnalysisCancellationToken()..cancel();

    final result = await const VideoPlayerLocalMediaAssetAnalyzer().analyze(
      MediaAssetAnalysisRequest(
        assetId: 'asset-cancelled',
        filePath: mediaFile.path,
        cancellationToken: cancellation,
      ),
    );

    expect(result.status, MediaAssetAnalysisStatus.cancelled);
    expect(fakePlatform.lastDataSource, isNull);
  });
}
