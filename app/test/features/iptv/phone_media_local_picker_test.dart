import 'dart:io';

import 'package:airo_app/features/iptv/phone_media_local_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_media/platform_media.dart';
import 'package:platform_player/platform_player.dart';
// Transitive via file_picker; direct import keeps the test helper typed.
// ignore: depend_on_referenced_packages
import 'package:cross_file/cross_file.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('test/phone_media_picker');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    FilePickerPlatform.instance = MethodChannelFilePicker();
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

  test('platform exception during Android pick returns null', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'cancel');
    });

    expect(await pickAndroidPhoneLocalMediaForTv(channel: channel), isNull);
  });

  test('uses default analyzer when none is supplied', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'pickVideo') {
        return <String, Object?>{
          'token': 'lease-4',
          'descriptor': 44,
          'filePath': '/proc/self/fd/44',
          'title': 'clip.mp4',
          'size': 2048,
        };
      }
      return null;
    });

    final item = await pickAndroidPhoneLocalMediaForTv(
      channel: channel,
      analyzer: const _UnsupportedAnalyzer(),
    );

    expect(item, isNotNull);
    expect(item!.container, 'mp4');
  });

  test('descriptor source exposes byte ranges until released', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'pickVideo') {
        return <String, Object?>{
          'token': 'lease-5',
          'descriptor': 45,
          'filePath': '/proc/self/fd/45',
          'title': 'clip.mp4',
          'size': 16,
        };
      }
      return null;
    });
    final item = await pickAndroidPhoneLocalMediaForTv(
      channel: channel,
      analyzer: const _UnsupportedAnalyzer(),
    );

    expect(item!.source!.isAvailable, isTrue);
    await item.sourceLease!.release();
    expect(item.source!.isAvailable, isFalse);
  });

  test('desktop file picker path maps analyzed media metadata', () async {
    const analyzerChannel = MethodChannel('com.airo.media_asset_analyzer');
    HostPlatformMediaAssetAnalyzer.debugSetMethodChannel(analyzerChannel);
    messenger.setMockMethodCallHandler(analyzerChannel, (call) async {
      if (call.method == 'analyze') {
        return {
          'status': 'complete',
          'profile': {
            'schemaVersion': '1.0.0',
            'assetId': 'sample.mov',
            'container': 'mov',
            'durationMs': 120000,
            'fileSizeBytes': 4,
            'videoTracks': [
              {
                'id': 'video-0',
                'codec': 'h264',
                'width': 1920,
                'height': 1080,
                'dynamicRange': 'sdr',
                'confidence': 'exact',
              },
            ],
            'audioTracks': [
              {
                'id': 'audio-0',
                'codec': 'aac',
                'confidence': 'exact',
              },
            ],
            'subtitleTracks': [],
            'warnings': [],
          },
          'diagnostics': {
            'elapsedMs': 1,
            'didUseMetadataProbe': true,
            'fileSizeBytes': 4,
          },
        };
      }
      return null;
    });

    final tempDir = await Directory.systemTemp.createTemp('phone-media');
    final file = File('${tempDir.path}/sample.mov');
    await file.writeAsBytes([0, 1, 2, 3]);
    FilePickerPlatform.instance = _FakeFilePickerPlatform(
      _TestPlatformFile(path: file.path, name: 'sample.mov', size: 4),
    );

    final item = await pickPhoneLocalMediaForTv();

    expect(item, isNotNull);
    expect(item!.title, 'sample.mov');
    expect(item.container, 'mov');
    expect(item.videoCodec, 'h264');
    expect(item.audioCodec, 'aac');
    await tempDir.delete(recursive: true);
  });

  test('desktop file picker cancel returns null', () async {
    FilePickerPlatform.instance = _FakeFilePickerPlatform(null);

    expect(await pickPhoneLocalMediaForTv(), isNull);
  });

  test('desktop file picker without a local path returns null', () async {
    FilePickerPlatform.instance = _FakeFilePickerPlatform(
      _TestPlatformFile(
        path: null,
        name: 'remote.mov',
        size: 4,
        uri: Uri.parse('content://media/external/video/1'),
      ),
    );

    expect(await pickPhoneLocalMediaForTv(), isNull);
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

final class _TestPlatformFile extends PlatformFile {
  _TestPlatformFile({
    required this.name,
    required this.size,
    String? path,
    Uri? uri,
  }) : _path = path,
       _uri = uri ?? Uri.file(path!);

  final String? _path;
  final Uri _uri;

  @override
  String? get path => _path ?? (_uri.scheme == 'file' ? _uri.toFilePath() : null);

  @override
  final String name;

  final int size;

  @override
  Uri get uri => _uri;

  @override
  Future<int> length() async => size;

  @override
  Stream<Uint8List> readAsByteStream() => const Stream.empty();

  @override
  Future<Uint8List> readAsBytes() async => Uint8List(0);

  @override
  XFile get xFile => XFile(uri.toString(), name: name, length: size);
}

class _FakeFilePickerPlatform extends FilePickerPlatform {
  _FakeFilePickerPlatform(this.file);

  final PlatformFile? file;

  @override
  Future<PlatformFile?> pickFile({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    return file;
  }
}
