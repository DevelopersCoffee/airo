import 'dart:io';

import 'package:core_entitlements/core_entitlements.dart';
import 'package:feature_mind/src/bridges/mind_generation_bridge.dart';
import 'package:feature_mind/src/bridges/mind_speech_bridge.dart';
import 'package:feature_mind/src/mind_service.dart';
import 'package:feature_mind/src/models/model_provider.dart';
import 'package:feature_mind/src/runtime/models/log_models.dart';
import 'package:feature_mind/src/whisper/api/meetings.dart' as rust;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_bridges.dart';
import 'support/recording_operation_log.dart';
import 'package:feature_mind/src/mind_diarization.dart';

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
  Future<void> dispose() async {}

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
    SharedPreferences.setMockInitialValues({});
    tempDir = Directory.systemTemp.createTempSync('mind_service_test_');
    PathProviderPlatform.instance = FakePathProviderPlatform(tempDir.path);
    speech = FakeMindSpeechBridge();
    generation = FakeMindGenerationBridge();
    service = MindService(
      recorder: MockAudioRecorder(),
      modelProvider: FakeReadyModelProvider(),
      speechBridge: speech,
      generationBridge: generation,
      entitlements: const NoEntitlements(),
    );
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  // T3 — the emitted MindStage sequence is exactly transcribing → extracting
  // → generating → saving → done. This is the contract that used to be enforced
  // by `user_journey.rs` running both real engines in one process; it cannot any
  // more (#1549), so this is where that property now lives.
  test(
    'T3: process emits transcribing, extracting, generating, saving, done in that order',
    () async {
      speech.transcriptEvents = const [
        TranscriptEventTranscribing(
          TranscriptSegment(id: 's0', startMs: 0, endMs: 500, text: 'hello'),
        ),
        TranscriptEventTranscriptReady('hello world', [
          TranscriptSegment(
            id: 's0',
            startMs: 0,
            endMs: 500,
            text: 'hello world',
          ),
        ]),
      ];
      generation.meetingIntelligenceEvents = const [
        MeetingIntelligenceEventExtracting(),
        MeetingIntelligenceEventGenerating('Min'),
        MeetingIntelligenceEventIrReady(
          decisions: [
            rust.MeetingDecisionRecord(
              id: 'd1',
              statement: 'ship it',
              status: rust.MeetingDecisionStatus.agreed,
              evidenceSegmentIds: ['s0'],
            ),
          ],
          actionItems: [],
          metrics: [],
        ),
        MeetingIntelligenceEventMinutesReady('Minutes.'),
      ];

      final stages = await service
          .process(wavPath: 'x.wav', title: 't')
          .map((p) => p.stage)
          .toList();

      expect(stages, [
        MindStage.transcribing,
        MindStage.transcribing,
        MindStage.extracting,
        MindStage.extracting,
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
        TranscriptEventTranscriptReady('hello world', [
          TranscriptSegment(
            id: 's0',
            startMs: 0,
            endMs: 500,
            text: 'hello world',
          ),
        ]),
      ];
      generation.meetingIntelligenceEvents = const [
        MeetingIntelligenceEventMinutesReady('Minutes.'),
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
        TranscriptEventTranscribing(
          TranscriptSegment(id: 's0', startMs: 0, endMs: 500, text: 'partial'),
        ),
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

  test(
    'T6b: MeetingIntelligenceEventCancelled yields idle and skips save',
    () async {
      speech.transcriptEvents = const [
        TranscriptEventTranscriptReady('hello', [
          TranscriptSegment(id: 's0', startMs: 0, endMs: 500, text: 'hello'),
        ]),
      ];
      generation.meetingIntelligenceEvents = const [
        MeetingIntelligenceEventCancelled(),
      ];

      final stages = await service
          .process(wavPath: 'x.wav', title: 't')
          .map((p) => p.stage)
          .toList();

      expect(stages.last, MindStage.idle);
      expect(speech.savedModel, isNull);
    },
  );

  // T7 — save() is called with the model id the GENERATION bridge reports,
  // not something process() invents. `ADR-0018 §5`: what produced a summary
  // is recorded with it.
  test('T7: save receives the generation bridge\'s model id', () async {
    speech.transcriptEvents = const [
      TranscriptEventTranscriptReady('hello world', [
        TranscriptSegment(
          id: 's0',
          startMs: 0,
          endMs: 500,
          text: 'hello world',
        ),
      ]),
    ];
    generation.meetingIntelligenceEvents = const [
      MeetingIntelligenceEventMinutesReady('Minutes.'),
    ];
    generation.modelIdValue = 'airo.generation.compact@1';

    await service.process(wavPath: 'x.wav', title: 't').drain<void>();

    expect(speech.savedModel, 'airo.generation.compact@1');
  });

  // `#1629` Gap D — the segments `TranscriptEventTranscriptReady` carried and
  // the wav path `process()` was given must both reach `save`, unchanged, so
  // `save_meeting` can persist them into `transcript.json`. Without this,
  // "reproducible" would be a Rust-only property that Dart quietly drops on
  // its way to the store, the same failure mode `#1629` found in the ASR
  // segment IDs themselves.
  test('T7b: save receives the transcript segments and the wav path unchanged', () async {
    const segments = [
      TranscriptSegment(id: 's0', startMs: 0, endMs: 500, text: 'hello'),
      TranscriptSegment(id: 's1', startMs: 500, endMs: 900, text: 'world'),
    ];
    speech.transcriptEvents = const [
      TranscriptEventTranscriptReady('hello world', segments),
    ];
    generation.meetingIntelligenceEvents = const [
      MeetingIntelligenceEventMinutesReady('Minutes.'),
    ];

    await service
        .process(wavPath: 'recording-1.wav', title: 't')
        .drain<void>();

    expect(
      speech.savedSegments,
      applySoloSpeakerDiarization(segments),
    );
    expect(speech.savedWavPath, 'recording-1.wav');
  });

  test('T7c: save receives IR fields from the intelligence pipeline', () async {
    speech.transcriptEvents = const [
      TranscriptEventTranscriptReady('hello world', [
        TranscriptSegment(
          id: 's0',
          startMs: 0,
          endMs: 500,
          text: 'hello world',
        ),
      ]),
    ];
    generation.meetingIntelligenceEvents = const [
      MeetingIntelligenceEventIrReady(
        decisions: [
          rust.MeetingDecisionRecord(
            id: 'd1',
            statement: 'ship it',
            status: rust.MeetingDecisionStatus.agreed,
            evidenceSegmentIds: ['s0'],
          ),
        ],
        actionItems: [
          rust.MeetingActionItemRecord(
            id: 'a1',
            task: 'write tests',
            owner: 'Priya',
            due: 'Friday',
            status: rust.MeetingActionStatus.open,
            evidenceSegmentIds: ['s0'],
          ),
        ],
        metrics: const [],
      ),
      MeetingIntelligenceEventMinutesReady('Minutes.'),
    ];

    await service.process(wavPath: 'x.wav', title: 'Standup').drain<void>();

    expect(speech.savedDecisions, hasLength(1));
    expect(speech.savedActionItems, hasLength(1));
    expect(speech.savedDecisions!.single.statement, 'ship it');
    expect(speech.savedActionItems!.single.task, 'write tests');
  });

  test(
    'T7d: process appends meetingIrExtracted to the operation log on success',
    () async {
      final log = RecordingOperationLog();
      final serviceWithLog = MindService(
        recorder: MockAudioRecorder(),
        modelProvider: FakeReadyModelProvider(),
        speechBridge: speech,
        generationBridge: generation,
        operationLog: log,
        meetingContextId: 'scribe-test',
      );
      speech.transcriptEvents = const [
        TranscriptEventTranscriptReady('hello world', [
          TranscriptSegment(
            id: 's0',
            startMs: 0,
            endMs: 500,
            text: 'hello world',
          ),
        ]),
      ];
      generation.meetingIntelligenceEvents = const [
        MeetingIntelligenceEventIrReady(
          decisions: [
            rust.MeetingDecisionRecord(
              id: 'd1',
              statement: 'ship it',
              status: rust.MeetingDecisionStatus.agreed,
              evidenceSegmentIds: ['s0'],
            ),
          ],
          actionItems: [
            rust.MeetingActionItemRecord(
              id: 'a1',
              task: 'write tests',
              owner: 'Priya',
              due: 'Friday',
              status: rust.MeetingActionStatus.open,
              evidenceSegmentIds: ['s0'],
            ),
          ],
          metrics: const [],
        ),
        MeetingIntelligenceEventMinutesReady('Minutes.'),
      ];

      await serviceWithLog
          .process(wavPath: 'x.wav', title: 'Standup')
          .drain<void>();

      expect(log.appended, hasLength(1));
      final op = log.appended.single;
      expect(op.kind, MindOpKind.meetingIrExtracted);
      expect(op.title, 'Standup minutes extracted');
      expect(op.contextId, 'scribe-test');
      expect(op.detail, contains('decisions=1'));
      expect(op.detail, contains('action_items=1'));
      expect(op.detail, contains('metrics=0'));
    },
  );

  // T8 — a bridge that throws surfaces as MindStage.failed with the message,
  // not an unhandled exception reaching the widget layer.
  test(
    'T8: a save failure surfaces as MindStage.failed, not an exception',
    () async {
      speech.transcriptEvents = const [
        TranscriptEventTranscriptReady('hello world', [
          TranscriptSegment(
            id: 's0',
            startMs: 0,
            endMs: 500,
            text: 'hello world',
          ),
        ]),
      ];
      generation.meetingIntelligenceEvents = const [
        MeetingIntelligenceEventMinutesReady('Minutes.'),
      ];
      speech.saveError = StateError('disk full');

      final progresses = await service
          .process(wavPath: 'x.wav', title: 't')
          .toList();

      expect(progresses.last.stage, MindStage.failed);
      expect(progresses.last.error, contains('disk full'));
    },
  );

  // `#1629` Gap C — `MindService.initialize` defaults to the English-only
  // model (today's behaviour, unchanged) and threads an explicit multilingual
  // request through to the bridge unchanged. This is the Dart-facing end of
  // the language-selection mechanism `models.rs`'s `resolve` tests prove on
  // the Rust side.
  group('initialize threads speechLanguage to the bridge', () {
    test('defaults to englishOnly when not specified', () async {
      await service.initialize();

      expect(speech.initializedSpeechLanguage, rust.SpeechLanguage.englishOnly);
    });

    test('passes multilingual through unchanged when requested', () async {
      await service.initialize(
        speechLanguage: rust.SpeechLanguage.multilingual,
      );

      expect(
        speech.initializedSpeechLanguage,
        rust.SpeechLanguage.multilingual,
      );
    });

    test(
      'uses defaultSpeechLanguage when initialize omits speechLanguage',
      () async {
        final multilingualDefault = MindService(
          recorder: MockAudioRecorder(),
          modelProvider: FakeReadyModelProvider(),
          speechBridge: speech,
          generationBridge: generation,
          defaultSpeechLanguage: rust.SpeechLanguage.multilingual,
        );
        await multilingualDefault.initialize();

        expect(
          speech.initializedSpeechLanguage,
          rust.SpeechLanguage.multilingual,
        );
      },
    );

    test('exposes speechLanguage for trust UX (#1774)', () async {
      expect(service.speechLanguage, rust.SpeechLanguage.englishOnly);
      await service.initialize(
        speechLanguage: rust.SpeechLanguage.multilingual,
      );
      expect(service.speechLanguage, rust.SpeechLanguage.multilingual);
      expect(
        service.scribeTrustState().languageBadgeLabel,
        'Multilingual · auto-detect',
      );
    });
  });

  // `#1664`: Settings pins a per-recording language, and `process()` is the
  // one place that pin has to reach the speech bridge -- everything below it
  // (the Rust `TranscriptionOptions` plumbing) is covered on the Rust side;
  // this is the Dart half of the same guarantee.
  group('process threads a language pin to the speech bridge (#1664)', () {
    test('a chosen language reaches transcribe() unchanged', () async {
      speech.transcriptEvents = const [
        TranscriptEventTranscriptReady('namaste', [
          TranscriptSegment(id: 's0', startMs: 0, endMs: 500, text: 'namaste'),
        ]),
      ];
      generation.meetingIntelligenceEvents = const [
        MeetingIntelligenceEventMinutesReady('Minutes.'),
      ];

      await service
          .process(wavPath: 'x.wav', title: 't', language: 'hi')
          .drain<void>();

      expect(speech.transcribeLanguage, 'hi');
    });

    test('no language chosen leaves the bridge on auto-detect (null)', () async {
      speech.transcriptEvents = const [
        TranscriptEventTranscriptReady('hello world', [
          TranscriptSegment(
            id: 's0',
            startMs: 0,
            endMs: 500,
            text: 'hello world',
          ),
        ]),
      ];
      generation.meetingIntelligenceEvents = const [
        MeetingIntelligenceEventMinutesReady('Minutes.'),
      ];

      await service.process(wavPath: 'x.wav', title: 't').drain<void>();

      expect(
        speech.transcribeLanguage,
        isNull,
        reason:
            'omitting language must not silently pin one -- auto-detect stays the default',
      );
    });
  });
}
