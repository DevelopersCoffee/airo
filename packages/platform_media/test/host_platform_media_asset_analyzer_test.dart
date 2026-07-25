import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_media/platform_media.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.airo.media_asset_analyzer');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    HostPlatformMediaAssetAnalyzer.debugSetMethodChannel(channel);
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('host analyzer parses a complete native payload', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'analyze');
      return {
        'status': 'complete',
        'profile': {
          'schemaVersion': '1.0.0',
          'assetId': 'asset-1',
          'container': 'mkv',
          'durationMs': 7807000,
          'fileSizeBytes': 6100000000,
          'overallBitrate': 6250000,
          'videoTracks': [
            {
              'id': 'video-0',
              'codec': 'hevc',
              'width': 3840,
              'height': 2160,
              'bitrate': 5800000,
              'dynamicRange': 'hdr10',
              'confidence': 'exact',
            },
          ],
          'audioTracks': [
            {
              'id': 'audio-0',
              'codec': 'dts',
              'language': 'eng',
              'channelCount': 6,
              'isDefault': true,
              'isCommentary': false,
              'confidence': 'exact',
            },
          ],
          'subtitleTracks': [
            {
              'id': 'subtitle-0',
              'format': 'pgs',
              'language': 'eng',
              'isDefault': true,
              'isForced': false,
              'isCommentary': false,
              'confidence': 'exact',
            },
          ],
          'warnings': ['overall_bitrate_estimated'],
        },
        'diagnostics': {
          'elapsedMs': 120,
          'didUseMetadataProbe': true,
          'fileSizeBytes': 6100000000,
        },
      };
    });

    final result = await HostPlatformMediaAssetAnalyzer().analyze(
      const MediaAssetAnalysisRequest(
        assetId: 'asset-1',
        filePath: '/private/tmp/movie.mkv',
        fileName: 'movie.mkv',
      ),
    );

    expect(result.status, MediaAssetAnalysisStatus.complete);
    expect(result.profile?.container, MediaAssetContainer.mkv);
    expect(result.profile?.videoTracks.single.codec, MediaVideoCodec.hevc);
    expect(
      result.profile?.videoTracks.single.dynamicRange,
      MediaDynamicRangeProfile.hdr10,
    );
    expect(result.profile?.audioTracks.single.codec, MediaAudioCodec.dts);
    expect(
      result.profile?.subtitleTracks.single.format,
      MediaSubtitleFormat.pgs,
    );
    expect(
      result.profile?.warnings,
      contains(MediaAssetWarningCode.overallBitrateEstimated),
    );
  });

  test(
    'default analyzer falls back when native inspection is unavailable',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw MissingPluginException();
      });

      final result =
          await DefaultLocalMediaAssetAnalyzer(
            fallbackAnalyzer: _FakeAnalyzer(
              const MediaAssetAnalysisResult(
                status: MediaAssetAnalysisStatus.partial,
                profile: MediaAssetProfile(
                  assetId: 'asset-fallback',
                  container: MediaAssetContainer.mp4,
                  videoTracks: [],
                  audioTracks: [],
                  subtitleTracks: [],
                  warnings: [MediaAssetWarningCode.videoCodecUnavailable],
                ),
                diagnostics: MediaAssetAnalysisDiagnostics(
                  elapsed: Duration(milliseconds: 1),
                  didUseMetadataProbe: true,
                ),
              ),
            ),
          ).analyze(
            const MediaAssetAnalysisRequest(
              assetId: 'asset-fallback',
              filePath: '/private/tmp/movie.mp4',
              fileName: 'movie.mp4',
            ),
          );

      expect(result.status, MediaAssetAnalysisStatus.partial);
      expect(result.profile?.assetId, 'asset-fallback');
    },
  );
}

class _FakeAnalyzer implements LocalMediaAssetAnalyzer {
  const _FakeAnalyzer(this.result);

  final MediaAssetAnalysisResult result;

  @override
  Future<MediaAssetAnalysisResult> analyze(
    MediaAssetAnalysisRequest request,
  ) async {
    return result;
  }
}
