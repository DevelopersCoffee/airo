import 'dart:io';

import 'package:feature_mind/src/bridges/mind_generation_bridge.dart';
import 'package:feature_mind/src/bridges/mind_speech_bridge.dart';
import 'package:feature_mind/src/mind_service.dart';
import 'package:feature_mind/src/models/model_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:record/record.dart';

import 'support/fake_bridges.dart';

/// `AudioRecorder`'s real constructor talks to a platform channel, which does
/// not exist in a plain `flutter_test` run. None of the tests here touch
/// recording -- only `process()` and `cancelProcessing()` -- so a bare mock
/// that never calls the real constructor is enough; nothing on it needs
/// stubbing.
class MockAudioRecorder extends Mock implements AudioRecorder {}

/// `MindService.modelsDirectory()` calls `path_provider`, which needs a
/// platform channel outside a real app. This is that channel, backed by a
/// real temp directory so the file operations in `MindService.initialize`
/// still exercise real I/O.
class FakePathProviderPlatform extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  FakePathProviderPlatform(this.supportPath);
  final String supportPath;

  @override
  Future<String?> getApplicationSupportPath() async => supportPath;
}

/// Reports every model as already installed, at the pinned size. `MindService`
/// only calls [acquire] when [isInstalled] is false, so a fixed `true` keeps
/// these tests inside `process()` rather than model acquisition, which
/// `download_model_provider_test.dart` already covers.
class FakeReadyModelProvider implements ModelProvider {
  @override
  Future<List<RequiredModel>> requiredModels() async => const [];

  @override
  bool get acquiresWithoutNetwork => true;

  @override
  Future<bool> isInstalled(Directory modelsDir) async => true;

  @override
  Future<List<RequiredModel>> missingModels(Directory modelsDir) async =>
      const [];

  @override
  Stream<ModelAcquisitionEvent> acquire(Directory modelsDir) =>
      const Stream.empty();

  @override
  Future<List<InstalledModel>> verify(Directory modelsDir) async => const [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late FakeMindSpeechBridge speech;
  late FakeMindGenerationBridge generation;
  late MindService service;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('mind_service_test_');
    PathProviderPlatform.instance = FakePathProviderPlatform(tempDir.path);
    speech = FakeMindSpeechBridge();
    generation = FakeMindGenerationBridge();
    service = MindService(
      recorder: MockAudioRecorder(),
      modelProvider: FakeReadyModelProvider(),
      speechBridge: speech,
      generationBridge: generation,
    );
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  // T3 — the emitted MindStage sequence is exactly transcribing -> generating
  // -> saving -> done. This is the contract that used to be enforced by
  // `user_journey.rs` running both real engines in one process; it cannot any
  // more (#1549), so this is where that property now lives.
  test(
    'T3: process emits transcribing, generating, saving, done in that order',
    () async {
      speech.transcriptEvents = const [
        TranscriptEventTranscribing('hello'),
        TranscriptEventTranscriptReady('hello world'),
      ];
      generation.generationEvents = const [
        GenerationEventGenerating('Min'),
        GenerationEventMinutesReady('Minutes.'),
      ];

      final stages = await service
          .process(wavPath: 'x.wav', title: 't')
          .map((p) => p.stage)
          .toList();

      expect(stages, [
        MindStage.transcribing,
        MindStage.transcribing,
        MindStage.generating,
        MindStage.generating,
        MindStage.saving,
        MindStage.done,
      ]);
    },
  );

  // T4 — cancelProcessing() cancels BOTH bridges once the generation bridge
  // has been loaded. Two engines now, two admission controls; a user who
  // presses Stop should not care which one is running, and the split (#1549)
  // is exactly what makes it possible to forget the second one.
  test(
    'T4: cancelProcessing cancels the generation bridge once it has loaded',
    () async {
      speech.transcriptEvents = const [
        TranscriptEventTranscriptReady('hello world'),
      ];
      generation.generationEvents = const [
        GenerationEventMinutesReady('Minutes.'),
      ];

      await service.process(wavPath: 'x.wav', title: 't').drain<void>();
      service.cancelProcessing();

      expect(speech.cancelCalls, 1);
      expect(
        generation.cancelCalls,
        1,
        reason:
            'generation was loaded during process(), so cancel must '
            'reach it too',
      );
    },
  );

  test(
    'T4b: cancelProcessing does not touch the generation bridge before it has '
    'ever loaded',
    () async {
      service.cancelProcessing();

      expect(speech.cancelCalls, 1);
      expect(generation.cancelCalls, 0);
    },
  );

  // T5 — a transcribe-only run (cancelled before generation) never loads the
  // 48 MB generation library. The lazy-load claim, made observable by
  // `MindGenerationBridge.ensureLoaded` rather than asserted by reading logs.
  test(
    'T5: a transcript-cancelled run never loads the generation bridge',
    () async {
      speech.transcriptEvents = const [TranscriptEventCancelled()];

      await service.process(wavPath: 'x.wav', title: 't').drain<void>();

      expect(generation.ensureLoadedCalls, 0);
      expect(generation.isLoaded, isFalse);
    },
  );

  // T6 — cancelling mid-transcribe yields `idle` and never reaches
  // generation. `user_journey.rs`'s cancel path, restated against the bridge
  // seam.
  test(
    'T6: TranscriptEventCancelled yields idle and skips generation entirely',
    () async {
      speech.transcriptEvents = const [
        TranscriptEventTranscribing('partial'),
        TranscriptEventCancelled(),
      ];

      final stages = await service
          .process(wavPath: 'x.wav', title: 't')
          .map((p) => p.stage)
          .toList();

      expect(stages.last, MindStage.idle);
      expect(generation.ensureLoadedCalls, 0);
    },
  );

  // T7 — save() is called with the model id the GENERATION bridge reports,
  // not something process() invents. `ADR-0018 §5`: what produced a summary
  // is recorded with it.
  test('T7: save receives the generation bridge\'s model id', () async {
    speech.transcriptEvents = const [
      TranscriptEventTranscriptReady('hello world'),
    ];
    generation.generationEvents = const [
      GenerationEventMinutesReady('Minutes.'),
    ];
    generation.modelIdValue = 'airo.generation.compact@1';

    await service.process(wavPath: 'x.wav', title: 't').drain<void>();

    expect(speech.savedModel, 'airo.generation.compact@1');
  });

  // T8 — a bridge that throws surfaces as MindStage.failed with the message,
  // not an unhandled exception reaching the widget layer.
  test(
    'T8: a save failure surfaces as MindStage.failed, not an exception',
    () async {
      speech.transcriptEvents = const [
        TranscriptEventTranscriptReady('hello world'),
      ];
      generation.generationEvents = const [
        GenerationEventMinutesReady('Minutes.'),
      ];
      speech.saveError = StateError('disk full');

      final progresses = await service
          .process(wavPath: 'x.wav', title: 't')
          .toList();

      expect(progresses.last.stage, MindStage.failed);
      expect(progresses.last.error, contains('disk full'));
    },
  );
}
