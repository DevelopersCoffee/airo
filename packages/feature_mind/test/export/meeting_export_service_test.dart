import 'package:feature_mind/src/export/application/meeting_export_service.dart';
import 'package:feature_mind/src/mind_service.dart';
import 'package:feature_mind/src/whisper/api/meetings.dart' as rust;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

/// `MindService` isn't an interface — it's mocked directly, same as
/// `mind_service_test.dart` mocks its own collaborators (`fake_bridges.dart`)
/// rather than standing up the real Rust bridge.
class MockMindService extends Mock implements MindService {}

rust.MeetingRecord _meeting({
  required String id,
  String title = 'Standup',
  int recordedAtMs = 1755000000000,
  String transcript = 'the flat transcript',
}) => rust.MeetingRecord(
  id: id,
  title: title,
  recordedAt: BigInt.from(recordedAtMs),
  transcript: transcript,
  minutes: '',
  model: 'qwen',
);

rust.TranscriptDocumentRecord _doc({
  required String meetingId,
  List<rust.TranscriptSegmentRecord> segments = const [],
}) => rust.TranscriptDocumentRecord(
  meetingId: meetingId,
  audioPath: '/tmp/$meetingId.wav',
  modelVersion: 'whisper-multilingual',
  segments: segments,
);

void main() {
  late MockMindService mind;
  late MeetingExportService service;

  setUp(() {
    mind = MockMindService();
    service = MeetingExportService(mind);
  });

  group('exportMeeting', () {
    test('returns null when the meeting no longer exists', () async {
      when(() => mind.meeting('gone')).thenAnswer((_) async => null);
      final result = await service.exportMeeting('gone');
      expect(result, isNull);
    });

    test(
      'uses timestamped segments when a transcript document exists',
      () async {
        when(
          () => mind.meeting('m1'),
        ).thenAnswer((_) async => _meeting(id: 'm1'));
        when(() => mind.transcriptDocument('m1')).thenAnswer(
          (_) async => _doc(
            meetingId: 'm1',
            segments: [
              rust.TranscriptSegmentRecord(
                id: 's1',
                startMs: BigInt.zero,
                endMs: BigInt.from(2000),
                text: 'Hello team.',
              ),
              rust.TranscriptSegmentRecord(
                id: 's2',
                startMs: BigInt.from(2000),
                endMs: BigInt.from(5000),
                text: 'Let’s begin.',
              ),
            ],
          ),
        );

        final bundle = await service.exportMeeting('m1');

        expect(bundle, isNotNull);
        expect(bundle!.folderName, contains('standup'));
        final transcript = bundle.files['transcript.md']!;
        expect(transcript, contains('[00:00:00] Hello team.'));
        expect(transcript, contains('[00:00:02] Let’s begin.'));
        // The flat MeetingRecord.transcript is not used when segments exist.
        expect(transcript, isNot(contains('the flat transcript')));
      },
    );

    test(
      'falls back to the flat transcript when no document is stored',
      () async {
        when(
          () => mind.meeting('m2'),
        ).thenAnswer((_) async => _meeting(id: 'm2'));
        when(() => mind.transcriptDocument('m2')).thenAnswer((_) async => null);

        final bundle = await service.exportMeeting('m2');

        expect(bundle, isNotNull);
        final transcript = bundle!.files['transcript.md']!;
        expect(transcript, contains('the flat transcript'));
        expect(transcript, isNot(contains('[00:')));
        // No document -> no derivable duration.
        expect(transcript, isNot(contains('duration:')));
      },
    );

    test(
      'does not yet populate mom.md -- no FFI surface for MoM generation',
      () async {
        when(
          () => mind.meeting('m3'),
        ).thenAnswer((_) async => _meeting(id: 'm3'));
        when(() => mind.transcriptDocument('m3')).thenAnswer((_) async => null);

        final bundle = await service.exportMeeting('m3');

        expect(bundle!.files.keys, ['transcript.md']);
      },
    );

    test(
      'renders correctly even past the off-main isolate threshold',
      () async {
        final longText = 'word ' * 20000; // well past 50 KB
        when(
          () => mind.meeting('big'),
        ).thenAnswer((_) async => _meeting(id: 'big', transcript: longText));
        when(
          () => mind.transcriptDocument('big'),
        ).thenAnswer((_) async => null);

        final bundle = await service.exportMeeting('big');

        expect(bundle, isNotNull);
        expect(bundle!.files['transcript.md'], contains(longText.trim()));
      },
    );
  });

  group('exportMeetings (batch)', () {
    test(
      'skips meetings that no longer exist, keeps the rest in order',
      () async {
        when(
          () => mind.meeting('a'),
        ).thenAnswer((_) async => _meeting(id: 'a', title: 'First'));
        when(() => mind.transcriptDocument('a')).thenAnswer((_) async => null);
        when(() => mind.meeting('missing')).thenAnswer((_) async => null);
        when(
          () => mind.meeting('b'),
        ).thenAnswer((_) async => _meeting(id: 'b', title: 'Second'));
        when(() => mind.transcriptDocument('b')).thenAnswer((_) async => null);

        final bundles = await service.exportMeetings(['a', 'missing', 'b']);

        expect(bundles, hasLength(2));
        expect(bundles[0].folderName, contains('first'));
        expect(bundles[1].folderName, contains('second'));
      },
    );

    test('empty id list returns no bundles and touches nothing', () async {
      final bundles = await service.exportMeetings(const []);
      expect(bundles, isEmpty);
      verifyNever(() => mind.meeting(any()));
    });

    test(
      'all-missing ids return an empty batch rather than throwing',
      () async {
        when(() => mind.meeting('x')).thenAnswer((_) async => null);
        final bundles = await service.exportMeetings(['x']);
        expect(bundles, isEmpty);
      },
    );
  });
}
