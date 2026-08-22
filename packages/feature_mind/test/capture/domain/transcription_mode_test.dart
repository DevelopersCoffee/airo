import 'package:flutter_test/flutter_test.dart';

import 'package:feature_mind/src/capture/domain/transcription_mode.dart';

void main() {
  test('default is after recording', () {
    expect(TranscriptionMode.fallback, TranscriptionMode.afterRecording);
  });

  test('live modes flag pipeline and post pass correctly', () {
    expect(TranscriptionMode.live.usesLivePipeline, isTrue);
    expect(TranscriptionMode.live.runsPostRecordingPass, isFalse);
    expect(TranscriptionMode.liveRefine.usesLivePipeline, isTrue);
    expect(TranscriptionMode.liveRefine.runsPostRecordingPass, isTrue);
    expect(TranscriptionMode.afterRecording.usesLivePipeline, isFalse);
  });

  test('fromStorageValue round trips', () {
    expect(
      TranscriptionMode.fromStorageValue('live'),
      TranscriptionMode.live,
    );
    expect(
      TranscriptionMode.fromStorageValue('unknown'),
      TranscriptionMode.afterRecording,
    );
  });
}
