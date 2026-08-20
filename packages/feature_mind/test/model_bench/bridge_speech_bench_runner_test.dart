import 'package:feature_mind/src/bridges/mind_speech_bridge.dart';
import 'package:feature_mind/src/model_bench/bridge_speech_bench_runner.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_bridges.dart';

void main() {
  test('refuses to sample when the speech engine is not loaded', () async {
    final runner = BridgeSpeechBenchRunner(
      FakeMindSpeechBridge(),
      wavPath: '/tmp/clip.wav',
      audioDurationMs: 1000,
    );
    await expectLater(runner.sample(), throwsStateError);
  });

  test('refuses a zero-duration clip rather than reporting RTFx 0', () async {
    final bridge = FakeMindSpeechBridge();
    await bridge.initialize(
      modelsDir: '/tmp',
      storePath: '/tmp/store',
      memoryBudgetMb: 512,
    );
    final runner = BridgeSpeechBenchRunner(
      bridge,
      wavPath: '/tmp/clip.wav',
      audioDurationMs: 0,
    );
    await expectLater(runner.sample(), throwsStateError);
  });

  test('times a drained transcribe when the engine is ready', () async {
    final bridge = FakeMindSpeechBridge()
      ..transcriptEvents = const [TranscriptEventCancelled()];
    await bridge.initialize(
      modelsDir: '/tmp',
      storePath: '/tmp/store',
      memoryBudgetMb: 512,
    );

    final sample = await BridgeSpeechBenchRunner(
      bridge,
      wavPath: '/tmp/clip.wav',
      audioDurationMs: 2000,
      language: 'en',
    ).sample();

    expect(sample.audioDurationMs, 2000);
    expect(sample.wallMs, greaterThanOrEqualTo(0));
    expect(bridge.transcribeLanguage, 'en');
  });
}
