import 'speech_bench_protocol.dart';

/// One transcribe() cycle used by [runSpeechBench].
///
/// Throws rather than inventing RTFx when the speech engine is not loaded.
/// This file does not import the generated whisper bridge.
abstract interface class SpeechBenchRunner {
  Future<SpeechBenchSample> sample();
}
