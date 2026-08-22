import 'package:feature_mind/feature_mind.dart';
import 'package:feature_mind/src/meeting_ir/meeting_ir_user_edits.dart';
import 'package:feature_mind/src/meeting_ir/meeting_ir_user_edits_store.dart';
import 'package:feature_mind/src/whisper/api/meetings.dart' as rust;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeMind extends MindService {
  _FakeMind({this.library = const [], this.doc});

  final List<rust.MeetingRecord> library;
  final rust.TranscriptDocumentRecord? doc;
  rust.MeetingRecord? lastStatusUpdate;

  @override
  Future<MindStatus> initialize({rust.SpeechLanguage? speechLanguage}) async =>
      const MindStatus.ready();

  @override
  Future<List<rust.MeetingRecord>> meetings() async => library;

  @override
  Future<rust.MeetingRecord?> meeting(String id) async =>
      library.where((m) => m.id == id).firstOrNull;

  @override
  Future<rust.TranscriptDocumentRecord?> transcriptDocument(
    String meetingId,
  ) async => doc;

  @override
  Future<rust.MeetingRecord> updateActionItemStatus({
    required rust.MeetingRecord meeting,
    required String actionItemId,
    required rust.MeetingActionStatus status,
  }) async {
    final updated = rust.MeetingRecord(
      id: meeting.id,
      title: meeting.title,
      recordedAt: meeting.recordedAt,
      transcript: meeting.transcript,
      minutes: meeting.minutes,
      model: meeting.model,
      decisions: meeting.decisions,
      actionItems: [
        for (final item in meeting.actionItems)
          if (item.id == actionItemId)
            rust.MeetingActionItemRecord(
              id: item.id,
              task: item.task,
              owner: item.owner,
              due: item.due,
              status: status,
              evidenceSegmentIds: item.evidenceSegmentIds,
            )
          else
            item,
      ],
      metrics: meeting.metrics,
    );
    lastStatusUpdate = updated;
    return updated;
  }

  @override
  Future<void> dispose() async {}

  @override
  Future<void> pauseRecording() async {}

  @override
  Future<void> resumeRecording() async {}
}

rust.MeetingRecord _irMeeting() => rust.MeetingRecord(
  id: 'm1700000000123',
  title: 'Platform standup',
  recordedAt: BigInt.from(1700000000),
  transcript: 'Priya said the Kafka consumer lag is the bottleneck.',
  minutes: '- Add three pods before Friday',
  model: 'qwen2.5-0.5b-instruct-q4_k_m',
  decisions: const [
    rust.MeetingDecisionRecord(
      id: 'd1',
      statement: 'Add three pods before Friday',
      status: rust.MeetingDecisionStatus.agreed,
      evidenceSegmentIds: ['s0'],
    ),
  ],
  actionItems: const [
    rust.MeetingActionItemRecord(
      id: 'a1',
      task: 'Add three pods',
      owner: 'Priya',
      status: rust.MeetingActionStatus.open,
      evidenceSegmentIds: ['s0'],
    ),
  ],
  metrics: const [
    rust.MeetingMetricRecord(
      id: 'n1',
      name: 'lag',
      value: '2s',
      evidenceSegmentIds: ['s0'],
    ),
  ],
);

rust.TranscriptDocumentRecord _doc() => rust.TranscriptDocumentRecord(
  meetingId: 'm1700000000123',
  audioPath: '/tmp/a.wav',
  modelVersion: 'whisper',
  segments: [
    rust.TranscriptSegmentRecord(
      id: 's0',
      startMs: BigInt.from(65000),
      endMs: BigInt.from(70000),
      text: 'Priya said the Kafka consumer lag is the bottleneck.',
      speakerLabel: 'sp0',
    ),
  ],
);

Widget _app(Widget home) => MaterialApp(home: home);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('renders MoM sections from IR and hides free-form minutes', (
    tester,
  ) async {
    final meeting = _irMeeting();
    await tester.pumpWidget(
      _app(
        MeetingScreen.stored(
          service: _FakeMind(library: [meeting], doc: _doc()),
          meeting: meeting,
          userEditsStore: MeetingIrUserEditsStore(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Decisions'), findsOneWidget);
    expect(find.text('Action items'), findsOneWidget);
    expect(find.text('Metrics'), findsOneWidget);
    expect(find.text('Add three pods before Friday'), findsOneWidget);
    expect(find.text('Add three pods'), findsOneWidget);
    expect(find.text('lag: 2s'), findsOneWidget);
    // Evidence clock on the action row (65_000 ms → 01:05).
    expect(find.text('01:05'), findsOneWidget);
    // Transcript is below MoM sections — scroll it into the lazy ListView.
    await tester.scrollUntilVisible(
      find.text('Transcript'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    // Solo diarization label on the transcript segment.
    expect(find.byKey(const Key('meeting_ir_speaker_s0')), findsOneWidget);
    expect(find.text('Speaker 1'), findsOneWidget);
    // Free-form minutes fallback is suppressed when IR is present.
    expect(find.text('Minutes'), findsNothing);
  });

  testWidgets('empty IR hides empty sections and empty minutes template', (
    tester,
  ) async {
    final meeting = rust.MeetingRecord(
      id: 'm-empty',
      title: 'Empty IR',
      recordedAt: BigInt.from(1700000000),
      transcript: 'hello',
      minutes:
          '# Minutes of Meeting\n\n**Meeting:** Empty IR\n\n'
          '## Meeting Objective\n\n'
          'No objective was recorded for this meeting.\n\n'
          '## Key Discussion Points\n\n'
          'No discussion points were recorded for this meeting.\n\n'
          '## Decisions & Direction\n\n'
          '_No decisions recorded._\n',
      model: 'qwen',
      decisions: const [],
      actionItems: const [],
      metrics: const [],
    );
    await tester.pumpWidget(
      _app(
        MeetingScreen.stored(
          service: _FakeMind(library: [meeting]),
          meeting: meeting,
          userEditsStore: MeetingIrUserEditsStore(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Decisions'), findsNothing);
    expect(find.text('Action items'), findsNothing);
    expect(find.text('Metrics'), findsNothing);
    expect(find.text('No decisions recorded.'), findsNothing);
    expect(find.text('Minutes'), findsNothing);
    expect(find.text('Transcript'), findsOneWidget);
    expect(find.text('hello'), findsOneWidget);
  });

  testWidgets('checking an action writes status through the service', (
    tester,
  ) async {
    final meeting = _irMeeting();
    final service = _FakeMind(library: [meeting], doc: _doc());
    await tester.pumpWidget(
      _app(
        MeetingScreen.stored(
          service: service,
          meeting: meeting,
          userEditsStore: MeetingIrUserEditsStore(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('meeting_ir_action_check_a1')));
    await tester.pumpAndSettle();

    expect(
      service.lastStatusUpdate!.actionItems.single.status,
      rust.MeetingActionStatus.done,
    );
  });

  testWidgets('tapping a decision highlights evidence and reports seek ms', (
    tester,
  ) async {
    final meeting = _irMeeting();
    int? seekMs;
    await tester.pumpWidget(
      _app(
        MeetingScreen.stored(
          service: _FakeMind(library: [meeting], doc: _doc()),
          meeting: meeting,
          userEditsStore: MeetingIrUserEditsStore(),
          onSeekAudio: (ms) => seekMs = ms,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add three pods before Friday'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('meeting_ir_evidence_clock')), findsOneWidget);
    expect(find.textContaining('Evidence at 01:05'), findsOneWidget);
    expect(seekMs, 65000);
  });

  testWidgets('tapping a transcript timestamp seeks to that moment', (
    tester,
  ) async {
    final meeting = _irMeeting();
    int? seekMs;
    await tester.pumpWidget(
      _app(
        MeetingScreen.stored(
          service: _FakeMind(library: [meeting], doc: _doc()),
          meeting: meeting,
          userEditsStore: MeetingIrUserEditsStore(),
          onSeekAudio: (ms) => seekMs = ms,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('meeting_ir_seek_s0')),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('meeting_ir_seek_s0')));
    await tester.pumpAndSettle();

    expect(seekMs, 65000);
    expect(find.textContaining('Evidence at 01:05'), findsOneWidget);
  });

  testWidgets('user edit overlay wins over IR task text', (tester) async {
    final meeting = _irMeeting();
    SharedPreferences.setMockInitialValues({
      'mind.meeting_ir.user_edits.m1700000000123': const MeetingIrUserEdits()
          .upsert('a1', const MeetingActionUserEdit(task: 'Ship four pods'))
          .encode(),
    });
    await tester.pumpWidget(
      _app(
        MeetingScreen.stored(
          service: _FakeMind(library: [meeting], doc: _doc()),
          meeting: meeting,
          userEditsStore: MeetingIrUserEditsStore(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ship four pods'), findsOneWidget);
    expect(find.text('Add three pods'), findsNothing);
  });

  testWidgets('low-tier banner offers cloud fallback without crashing', (
    tester,
  ) async {
    final meeting = _irMeeting();
    var cloud = false;
    await tester.pumpWidget(
      _app(
        MeetingScreen.stored(
          service: _FakeMind(library: [meeting], doc: _doc()),
          meeting: meeting,
          showLowTierCloudChoice: true,
          onCloudFallback: () => cloud = true,
          userEditsStore: MeetingIrUserEditsStore(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('meeting_ir_cloud_fallback')), findsOneWidget);
    await tester.tap(find.byKey(const Key('meeting_ir_cloud_fallback')));
    await tester.pumpAndSettle();
    expect(cloud, isTrue);
  });
}
