import 'dart:io';

import 'package:feature_mind/src/bridges/mind_generation_bridge.dart';
import 'package:feature_mind/src/bridges/mind_speech_bridge.dart';
import 'package:feature_mind/src/capture/application/meeting_processing_job_runner.dart';
import 'package:feature_mind/src/capture/domain/audio_retention_policy.dart';
import 'package:feature_mind/src/capture/domain/meeting_processing_job.dart';
import 'package:feature_mind/src/mind_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:record/record.dart';

import '../../support/fake_bridges.dart';

/// `AudioRecorder`'s real constructor talks to a platform channel that does
/// not exist in a plain `flutter_test` run. Same shape `mind_service_test.dart`
/// already uses -- this runner never calls `MindService.start/stopRecording`,
/// so nothing on the mock needs stubbing.
class _MockAudioRecorder extends Mock implements AudioRecorder {}

/// Minimal fake so `MindService.modelsDirectory()` resolves without a real
/// platform channel -- same shape `mind_service_test.dart` already uses.
class _FakePathProviderPlatform extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProviderPlatform(this.basePath);

  final String basePath;

  @override
  Future<String?> getApplicationSupportPath() async => basePath;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late FakeMindSpeechBridge speech;
  late FakeMindGenerationBridge generation;
  late MindService mindService;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('job_runner_test_');
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
    speech = FakeMindSpeechBridge();
    generation = FakeMindGenerationBridge();
    mindService = MindService(
      recorder: _MockAudioRecorder(),
      speechBridge: speech,
      generationBridge: generation,
    );
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('runs the meeting through MindService.process and completes', () async {
    speech.transcriptEvents = const [
      TranscriptEventTranscriptReady('hello world', [
        TranscriptSegment(id: 's0', startMs: 0, endMs: 500, text: 'hello world'),
      ]),
    ];
    generation.generationEvents = const [
      GenerationEventMinutesReady('Minutes.'),
    ];
    final audioFile = File('${tempDir.path}/meeting.wav')..writeAsStringSync('audio');
    final runner = MeetingProcessingJobRunner(
      mindService: mindService,
      retentionPolicy: () => AudioRetentionPolicy.keepAfterTranscript,
    );

    await runner.call(
      MeetingProcessingJob(
        id: 'm1',
        audioPath: audioFile.path,
        title: 'Standup',
        enqueuedAtMs: 0,
      ),
    );

    expect(speech.savedWavPath, audioFile.path);
    // Kept: the file must still exist.
    expect(audioFile.existsSync(), isTrue);
  });

  test('deletes the source audio when retention policy says delete-after-transcript', () async {
    speech.transcriptEvents = const [
      TranscriptEventTranscriptReady('hello world', [
        TranscriptSegment(id: 's0', startMs: 0, endMs: 500, text: 'hello world'),
      ]),
    ];
    generation.generationEvents = const [
      GenerationEventMinutesReady('Minutes.'),
    ];
    final audioFile = File('${tempDir.path}/meeting.wav')..writeAsStringSync('audio');
    final runner = MeetingProcessingJobRunner(
      mindService: mindService,
      retentionPolicy: () => AudioRetentionPolicy.deleteAfterTranscript,
    );

    await runner.call(
      MeetingProcessingJob(
        id: 'm1',
        audioPath: audioFile.path,
        title: 'Standup',
        enqueuedAtMs: 0,
      ),
    );

    expect(audioFile.existsSync(), isFalse);
  });

  test('a failed pipeline stage throws, so the queue marks the job failed/retries it', () async {
    speech.transcriptEvents = const [
      TranscriptEventTranscriptReady('hello world', [
        TranscriptSegment(id: 's0', startMs: 0, endMs: 500, text: 'hello world'),
      ]),
    ];
    speech.saveError = Exception('store unavailable');
    generation.generationEvents = const [
      GenerationEventMinutesReady('Minutes.'),
    ];
    final audioFile = File('${tempDir.path}/meeting.wav')..writeAsStringSync('audio');
    final runner = MeetingProcessingJobRunner(
      mindService: mindService,
      retentionPolicy: () => AudioRetentionPolicy.deleteAfterTranscript,
    );

    await expectLater(
      runner.call(
        MeetingProcessingJob(
          id: 'm1',
          audioPath: audioFile.path,
          title: 'Standup',
          enqueuedAtMs: 0,
        ),
      ),
      throwsA(anything),
    );

    // A failed run must not delete the only copy of the audio -- there is
    // nothing to fall back on if it did.
    expect(audioFile.existsSync(), isTrue);
  });
}
