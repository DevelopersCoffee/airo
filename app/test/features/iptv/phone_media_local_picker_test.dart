import 'package:airo_app/features/iptv/phone_media_local_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_media/platform_media.dart';
import 'package:platform_player/platform_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('test/phone_media_picker');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test(
    'analyzes Android descriptor selection without reading file bytes',
    () async {
      final calls = <MethodCall>[];
      final analyzer = _RecordingAnalyzer(
        const MediaAssetAnalysisResult(
          status: MediaAssetAnalysisStatus.complete,
          profile: MediaAssetProfile(
            assetId: 'lease-1',
            container: MediaAssetContainer.mkv,
            duration: Duration(hours: 2, minutes: 10, seconds: 7),
            videoTracks: [
              MediaVideoTrackProfile(
                id: 'video-0',
                codec: MediaVideoCodec.hevc,
                dimensions: MediaAssetDimensions(width: 3840, height: 2160),
                dynamicRange: MediaDynamicRangeProfile.hdr10,
                confidence: MediaTrackConfidence.exact,
              ),
            ],
            audioTracks: [
              MediaAudioTrackProfile(
                id: 'audio-1',
                codec: MediaAudioCodec.dts,
                confidence: MediaTrackConfidence.exact,
              ),
            ],
            subtitleTracks: [],
            warnings: [],
          ),
          diagnostics: MediaAssetAnalysisDiagnostics(
            elapsed: Duration(milliseconds: 120),
            didUseMetadataProbe: true,
            fileSizeBytes: 6101307309,
          ),
        ),
      );
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'pickVideo') {
          return <String, Object?>{
            'token': 'lease-1',
            'descriptor': 42,
            'filePath': '/proc/self/fd/42',
            'title': 'Feature.FILM.MKV',
            'size': 6101307309,
          };
        }
        return null;
      });

      final item = await pickAndroidPhoneLocalMediaForTv(
        channel: channel,
        analyzer: analyzer,
      );

      expect(item, isNotNull);
      expect(item!.filePath, '/proc/self/fd/42');
      expect(item.title, 'Feature.FILM.MKV');
      expect(item.container, 'mkv');
      expect(item.videoCodec, 'hevc');
      expect(item.audioCodec, 'dts');
      expect(item.duration, const Duration(hours: 2, minutes: 10, seconds: 7));
      expect(item.source, isA<PhoneMediaSeekableSource>());
      expect(await item.source!.length(), 6101307309);
      expect(analyzer.requests, [
        const MediaAssetAnalysisRequest(
          assetId: 'lease-1',
          filePath: '/proc/self/fd/42',
          fileName: 'Feature.FILM.MKV',
          fileSizeBytesHint: 6101307309,
        ),
      ]);
      expect(calls.map((call) => call.method), ['pickVideo']);
    },
  );

  test('cancel returns null', () async {
    messenger.setMockMethodCallHandler(channel, (_) async => null);

    expect(await pickAndroidPhoneLocalMediaForTv(channel: channel), isNull);
  });

  test('source lease releases native descriptor once', () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'pickVideo') {
        return <String, Object?>{
          'token': 'lease-2',
          'descriptor': 43,
          'filePath': '/proc/self/fd/43',
          'title': 'movie.mp4',
          'size': 4096,
        };
      }
      return null;
    });
    final item = await pickAndroidPhoneLocalMediaForTv(
      channel: channel,
      analyzer: const _UnsupportedAnalyzer(),
    );

    await item!.sourceLease!.release();
    await item.sourceLease!.release();

    expect(calls.map((call) => call.method), ['pickVideo', 'release']);
    expect(calls.last.arguments, {'token': 'lease-2'});
    expect(item.source!.isAvailable, isFalse);
    expect(
      item.source!.length(),
      throwsA(
        isA<PhoneMediaSourceException>().having(
          (error) => error.code,
          'code',
          PhoneMediaSourceFailureCode.closed,
        ),
      ),
    );
  });

  test('malformed selection releases a supplied native token', () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'pickVideo') {
        return <String, Object?>{'token': 'lease-3'};
      }
      return null;
    });

    expect(await pickAndroidPhoneLocalMediaForTv(channel: channel), isNull);
    expect(calls.map((call) => call.method), ['pickVideo', 'release']);
  });
}

class _RecordingAnalyzer implements LocalMediaAssetAnalyzer {
  _RecordingAnalyzer(this.result);

  final MediaAssetAnalysisResult result;
  final List<MediaAssetAnalysisRequest> requests = [];

  @override
  Future<MediaAssetAnalysisResult> analyze(
    MediaAssetAnalysisRequest request,
  ) async {
    requests.add(request);
    return result;
  }
}

class _UnsupportedAnalyzer implements LocalMediaAssetAnalyzer {
  const _UnsupportedAnalyzer();

  @override
  Future<MediaAssetAnalysisResult> analyze(
    MediaAssetAnalysisRequest request,
  ) async {
    return const MediaAssetAnalysisResult(
      status: MediaAssetAnalysisStatus.unsupportedInspection,
      diagnostics: MediaAssetAnalysisDiagnostics(
        elapsed: Duration.zero,
        didUseMetadataProbe: false,
      ),
    );
  }
}
