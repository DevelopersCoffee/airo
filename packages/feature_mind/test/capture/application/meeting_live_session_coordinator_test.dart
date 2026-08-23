import 'dart:async';

import 'package:feature_mind/src/bridges/mind_speech_bridge.dart';
import 'package:feature_mind/src/capture/application/meeting_live_session_coordinator.dart';
import 'package:feature_mind/src/capture/domain/live_insight.dart';
import 'package:feature_mind/src/whisper/api/meetings.dart' as rust;
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_bridges.dart';
import '../../support/fake_live_pcm_shim.dart';

void main() {
  test('stable segments accumulate and partial tail clears on stable', () async {
    final bridge = FakeMindSpeechBridge();
    final shim = FakeLivePcmShim();
    final controller = StreamController<TranscriptEvent>();
    bridge.transcriptEvents = [];

    final coordinator = MeetingLiveSessionCoordinator(
      speechBridge: _LiveSessionBridge(bridge, controller),
      pcmShim: shim,
    );

    unawaited(coordinator.start(meetingId: 'm1'));

    controller.add(
      TranscriptEventDelta(
        TranscriptDelta(
          sessionId: 'm1',
          segmentId: 's0',
          text: 'hello',
          startMs: 0,
          endMs: 1000,
          state: rust.TranscriptSegmentStateWire.partial,
          speakerLabel: 'sp0',
        ),
      ),
    );
    await pumpEventQueue();

    expect(coordinator.partialText, 'hello');
    expect(coordinator.transcriptLines.length, 1);
    expect(coordinator.transcriptLines.first.isPartial, isTrue);
    expect(coordinator.activeSpeakerIndex, 0);

    controller.add(
      TranscriptEventDelta(
        TranscriptDelta(
          sessionId: 'm1',
          segmentId: 's0',
          text: 'hello there',
          startMs: 0,
          endMs: 1200,
          state: rust.TranscriptSegmentStateWire.stable,
          speakerLabel: 'sp0',
        ),
      ),
    );
    await pumpEventQueue();

    expect(coordinator.partialText, isNull);
    expect(coordinator.stableSegments.length, 1);
    expect(coordinator.stableSegments.first.text, 'hello there');
    expect(coordinator.speakerActivitySpans.length, 1);
    expect(coordinator.speakerActivitySpans.first.speakerIndex, 0);

    await coordinator.cancel();
    await controller.close();
  });

  test('degraded message is retained for UI surfacing', () async {
    final bridge = FakeMindSpeechBridge();
    final shim = FakeLivePcmShim();
    final controller = StreamController<TranscriptEvent>();

    final coordinator = MeetingLiveSessionCoordinator(
      speechBridge: _LiveSessionBridge(bridge, controller),
      pcmShim: shim,
    );

    unawaited(coordinator.start(meetingId: 'm2'));
    controller.add(
      const TranscriptEventDegraded('Live transcript quality reduced'),
    );
    await pumpEventQueue();

    expect(coordinator.degradedMessage, 'Live transcript quality reduced');

    await coordinator.cancel();
    await controller.close();
  });

  test('conversation IR events populate the insights rail model', () async {
    final bridge = FakeMindSpeechBridge();
    final shim = FakeLivePcmShim();
    final controller = StreamController<TranscriptEvent>();

    final coordinator = MeetingLiveSessionCoordinator(
      speechBridge: _LiveSessionBridge(bridge, controller),
      pcmShim: shim,
    );

    unawaited(coordinator.start(meetingId: 'm-ir'));
    controller.add(
      const TranscriptEventConversationIr(
        '{"type":"decision","text":"We decided Friday","evidence":"s0","confidence":0.86}',
      ),
    );
    controller.add(
      const TranscriptEventConversationIr(
        '{"type":"segment","segment_id":"s0","text":"hello","start_ms":0,"end_ms":1}',
      ),
    );
    await pumpEventQueue();

    expect(coordinator.insights.length, 1);
    expect(coordinator.insights.first.kind, LiveInsightKind.decision);
    expect(coordinator.insights.first.text, 'We decided Friday');

    await coordinator.cancel();
    await controller.close();
  });

  test('pause and resume gate the PCM shim', () async {
    final bridge = FakeMindSpeechBridge();
    final shim = FakeLivePcmShim();
    final controller = StreamController<TranscriptEvent>();

    final coordinator = MeetingLiveSessionCoordinator(
      speechBridge: _LiveSessionBridge(bridge, controller),
      pcmShim: shim,
    );

    await coordinator.start(meetingId: 'm3');
    expect(shim.startCalls, 1);

    await coordinator.pause();
    expect(shim.pauseCalls, 1);
    expect(shim.paused, isTrue);

    await coordinator.resume();
    expect(shim.resumeCalls, 1);
    expect(shim.paused, isFalse);

    await coordinator.cancel();
    await controller.close();
  });

  test('amplitude samples ring buffers recent levels', () async {
    final bridge = FakeMindSpeechBridge();
    final shim = FakeLivePcmShim();
    final controller = StreamController<TranscriptEvent>();

    final coordinator = MeetingLiveSessionCoordinator(
      speechBridge: _LiveSessionBridge(bridge, controller),
      pcmShim: shim,
    );

    await coordinator.start(meetingId: 'm4');
    for (var i = 0; i < 15; i++) {
      shim.emitAmplitude(i / 15.0);
    }
    await pumpEventQueue();

    expect(coordinator.amplitudeSamples.length, 12);
    expect(coordinator.amplitudeSamples.last, greaterThan(0.8));

    await coordinator.cancel();
    await controller.close();
  });

  test('start surfaces live admission errors to the caller', () async {
    final bridge = FakeMindSpeechBridge()
      ..liveStartError = StateError('OverBudget needs_mb=4096 budget_mb=512');
    final shim = FakeLivePcmShim();
    final coordinator = MeetingLiveSessionCoordinator(
      speechBridge: bridge,
      pcmShim: shim,
    );

    await expectLater(
      coordinator.start(meetingId: 'm-admit'),
      throwsA(isA<StateError>()),
    );
    expect(shim.startCalls, 0);
  });
}

/// Routes [startLiveSession] to a controllable stream for tests.
class _LiveSessionBridge implements MindSpeechBridge {
  _LiveSessionBridge(this._inner, this._liveStream);

  final FakeMindSpeechBridge _inner;
  final StreamController<TranscriptEvent> _liveStream;

  @override
  Future<void> loadLibrary() => _inner.loadLibrary();

  @override
  bool isReady() => _inner.isReady();

  @override
  Future<void> initialize({
    required String modelsDir,
    required String storePath,
    required int memoryBudgetMb,
    rust.SpeechLanguage speechLanguage = rust.SpeechLanguage.englishOnly,
  }) =>
      _inner.initialize(
        modelsDir: modelsDir,
        storePath: storePath,
        memoryBudgetMb: memoryBudgetMb,
        speechLanguage: speechLanguage,
      );

  @override
  Stream<TranscriptEvent> transcribe({
    required String wavPath,
    String? language,
  }) =>
      _inner.transcribe(wavPath: wavPath, language: language);

  @override
  Stream<TranscriptEvent> startLiveSession({
    required String meetingId,
    String? language,
  }) =>
      _liveStream.stream;

  @override
  void pushLivePcm({required String sessionId, required List<int> samples}) {}

  @override
  void pauseLiveSession({required String sessionId}) {}

  @override
  void resumeLiveSession({required String sessionId}) {}

  @override
  Future<void> stopLiveSession({
    required String sessionId,
    String? audioPath,
  }) async {}

  @override
  void cancelLiveSession({required String sessionId}) {}

  @override
  Future<String> save({
    required String title,
    required int recordedAtMs,
    required String transcript,
    required String minutes,
    required String model,
    required List<TranscriptSegment> segments,
    required String wavPath,
    List<rust.MeetingDecisionRecord> decisions = const [],
    List<rust.MeetingActionItemRecord> actionItems = const [],
    List<rust.MeetingMetricRecord> metrics = const [],
  }) =>
      _inner.save(
        title: title,
        recordedAtMs: recordedAtMs,
        transcript: transcript,
        minutes: minutes,
        model: model,
        segments: segments,
        wavPath: wavPath,
        decisions: decisions,
        actionItems: actionItems,
        metrics: metrics,
      );

  @override
  Future<rust.TranscriptDocumentRecord?> getTranscript(String meetingId) =>
      _inner.getTranscript(meetingId);

  @override
  void cancel() => _inner.cancel();

  @override
  Future<List<rust.MeetingRecord>> meetings() => _inner.meetings();

  @override
  Future<List<rust.SearchHit>> search(String query) => _inner.search(query);

  @override
  Future<rust.MeetingRecord?> meeting(String id) => _inner.meeting(id);
}
