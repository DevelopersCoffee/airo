import '../bridges/mind_speech_bridge.dart';
import 'speech_bench_protocol.dart';
import 'speech_bench_runner.dart';

/// Drains one [MindSpeechBridge.transcribe] and times it on the Dart wall
/// clock. [audioDurationMs] is the clip length the caller already knows
/// (WAV header / recorder duration) — not inferred from transcript
/// timestamps, which can be shorter than the file.
class BridgeSpeechBenchRunner implements SpeechBenchRunner {
  BridgeSpeechBenchRunner(
    this._bridge, {
    required this.wavPath,
    required this.audioDurationMs,
    this.language,
  });

  final MindSpeechBridge _bridge;
  final String wavPath;
  final int audioDurationMs;
  final String? language;

  @override
  Future<SpeechBenchSample> sample() async {
    if (!_bridge.isReady()) {
      throw StateError('speech engine is not loaded');
    }
    if (audioDurationMs <= 0) {
      throw StateError('audio duration is zero');
    }
    final sw = Stopwatch()..start();
    await _bridge
        .transcribe(wavPath: wavPath, language: language)
        .drain<void>();
    return SpeechBenchSample(
      audioDurationMs: audioDurationMs,
      wallMs: sw.elapsedMilliseconds,
    );
  }
}
