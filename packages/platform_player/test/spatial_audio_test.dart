import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_player/platform_player.dart';

void main() {
  group('AiroSpatialAudioMode', () {
    test('round-trips stableId', () {
      expect(
        AiroSpatialAudioMode.fromStableId('original'),
        AiroSpatialAudioMode.original,
      );
      expect(
        AiroSpatialAudioMode.fromStableId('spatial'),
        AiroSpatialAudioMode.spatial,
      );
      expect(AiroSpatialAudioMode.fromStableId('atmos'), isNull);
    });
  });

  group('AiroIdentitySpatialPcmProcessor', () {
    test('identity passthrough preserves samples and counts frames', () {
      final processor = AiroIdentitySpatialPcmProcessor();
      final input = AiroPcmAudioBuffer(
        sampleRateHz: 48000,
        channelCount: 2,
        encoding: AiroPcmSampleEncoding.pcm16LittleEndian,
        samples: Uint8List.fromList([0, 1, 2, 3, 4, 5, 6, 7]),
      );
      final output = processor.process(input);
      expect(output.samples, input.samples);
      expect(processor.framesProcessed, 2);
    });
  });

  group('AiroSpatialAudioTapResolver', () {
    test('video_player backend is opaque', () {
      final status = AiroSpatialAudioTapResolver.expectedForBackend(
        AiroPlaybackBackendKind.videoPlayer,
      );
      expect(status.tapKind, AiroSpatialAudioTapKind.opaqueBackend);
      expect(status.isTapActive, isFalse);
      expect(status.detailCodes, isNotEmpty);
    });

    test('media3 backend expects pcm tap', () {
      final status = AiroSpatialAudioTapResolver.expectedForBackend(
        AiroPlaybackBackendKind.media3,
      );
      expect(status.tapKind, AiroSpatialAudioTapKind.pcmAfterDecode);
      expect(status.processorInstalled, isTrue);
    });
  });

  group('FakeAiroPlaybackEngine spatial contract', () {
    test('defaults to Original and accepts Spatial mode toggle', () async {
      final engine = FakeAiroPlaybackEngine();
      expect(engine.spatialAudioMode, AiroSpatialAudioMode.original);

      final tap = await engine.querySpatialAudioTap();
      expect(tap.tapKind, AiroSpatialAudioTapKind.pcmAfterDecode);

      await engine.setSpatialAudioMode(AiroSpatialAudioMode.spatial);
      expect(engine.spatialAudioMode, AiroSpatialAudioMode.spatial);
      await engine.dispose();
    });
  });

  group('AiroSpatialAudioPlatform', () {
    test('parses native tap status map', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      const channel = MethodChannel('com.airo.player/spatial_audio');
      AiroSpatialAudioPlatform.debugSetMethodChannel(channel);

      ServicesBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (call) async {
          if (call.method == 'spatialAudioTapStatus') {
            return {
              'backend': 'media3',
              'tapKind': 'pcm_after_decode',
              'processorInstalled': true,
              'framesProcessed': 42,
              'detailCodes': ['identity_audio_processor'],
            };
          }
          return null;
        },
      );

      final status = await AiroSpatialAudioPlatform.queryTapStatus();
      expect(status, isNotNull);
      expect(status!.backendKind, AiroPlaybackBackendKind.media3);
      expect(status.framesProcessed, 42);
      expect(status.isTapActive, isTrue);
    });
  });
}
