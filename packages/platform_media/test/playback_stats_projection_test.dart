import 'package:flutter_test/flutter_test.dart';
import 'package:platform_media/platform_media.dart';
import 'package:platform_player/platform_player.dart';

void main() {
  test('projects only engine-reported codec and selected quality facts', () {
    final state = AiroPlaybackState(
      backendKind: AiroPlaybackBackendKind.videoPlayer,
      phase: AiroPlaybackEnginePhase.playing,
      selectedQualityId: '1080p',
      diagnostics: AiroPlaybackDiagnostics(
        backendId: 'video_player',
        codecName: 'h264',
      ),
      qualityOptions: const [
        AiroPlaybackQualityOption(
          id: '720p',
          label: '720p',
          width: 1280,
          height: 720,
          bitrateKbps: 2500,
        ),
        AiroPlaybackQualityOption(
          id: '1080p',
          label: '1080p',
          width: 1920,
          height: 1080,
          bitrateKbps: 5000,
        ),
      ],
    );

    expect(
      playbackStatsFromEngineState(state),
      const AiroPlaybackStats(
        codec: 'h264',
        width: 1920,
        height: 1080,
        bitrateKbps: 5000,
      ),
    );
  });

  test('does not invent values when the engine omits diagnostics', () {
    final state = AiroPlaybackState(
      backendKind: AiroPlaybackBackendKind.videoPlayer,
      phase: AiroPlaybackEnginePhase.playing,
    );

    expect(playbackStatsFromEngineState(state), isNull);
  });

  test('idle and stopped engines clear playback stats', () {
    for (final phase in [
      AiroPlaybackEnginePhase.idle,
      AiroPlaybackEnginePhase.stopped,
      AiroPlaybackEnginePhase.unavailable,
    ]) {
      final state = AiroPlaybackState(
        backendKind: AiroPlaybackBackendKind.videoPlayer,
        phase: phase,
        diagnostics: AiroPlaybackDiagnostics(
          backendId: 'video_player',
          codecName: 'h264',
        ),
      );

      expect(playbackStatsFromEngineState(state), isNull);
    }
  });
}
