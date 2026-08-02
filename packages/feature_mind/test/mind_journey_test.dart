import 'dart:async';

import 'package:feature_mind/feature_mind.dart';
import 'package:feature_mind/src/api/mind.dart' as rust;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A [MindService] with the native library removed.
///
/// The journey's Rust half is proven by `tests/user_journey.rs` against the
/// real models. What is left to prove here is that the screens render what the
/// pipeline produces — and that must run in CI, where no model is installed.
class _FakeMind extends MindService {
  _FakeMind({
    this.status = const MindStatus.ready(),
    this.library = const [],
    this.hits = const [],
    Stream<MindProgress>? progress,
  }) : _stream = progress;

  final MindStatus status;
  final List<rust.MeetingRecord> library;
  final List<rust.SearchHit> hits;
  final Stream<MindProgress>? _stream;

  bool cancelled = false;
  String? searched;

  @override
  Future<MindStatus> initialize() async => status;

  @override
  Future<List<rust.MeetingRecord>> meetings() async => library;

  @override
  Future<List<rust.SearchHit>> search(String query) async {
    searched = query;
    return hits;
  }

  @override
  Future<rust.MeetingRecord?> meeting(String id) async =>
      library.where((m) => m.id == id).firstOrNull;

  @override
  void cancelProcessing() => cancelled = true;

  @override
  Stream<MindProgress> process({
    required String wavPath,
    required String title,
  }) =>
      _stream ?? const Stream.empty();

  @override
  Future<void> dispose() async {}
}

rust.MeetingRecord _meeting({
  String id = 'm1',
  String title = 'Platform standup',
  String transcript = 'Priya said the Kafka consumer lag is the bottleneck.',
  String minutes = '- Add three pods before Friday',
}) {
  return rust.MeetingRecord(
    id: id,
    title: title,
    recordedAt: BigInt.from(1700000000),
    transcript: transcript,
    minutes: minutes,
    model: 'qwen2.5-0.5b-instruct-q4_k_m',
  );
}

Widget _app(Widget home) => MaterialApp(home: home);

void main() {
  group('the library', () {
    testWidgets('an empty library says how to start one', (tester) async {
      await tester.pumpWidget(_app(MindHomeScreen(service: _FakeMind())));
      await tester.pumpAndSettle();

      expect(find.text('No meetings yet. Press Record to start one.'),
          findsOneWidget);
      expect(find.text('Record'), findsOneWidget);
    });

    testWidgets('meetings are listed with a preview of their minutes',
        (tester) async {
      await tester.pumpWidget(
        _app(MindHomeScreen(service: _FakeMind(library: [_meeting()]))),
      );
      await tester.pumpAndSettle();

      expect(find.text('Platform standup'), findsOneWidget);
      expect(find.text('- Add three pods before Friday'), findsOneWidget);
    });

    /// The first-run state. It must be distinguishable from a broken build,
    /// because the fix is entirely different.
    testWidgets('missing models are named, not hidden behind a generic error',
        (tester) async {
      await tester.pumpWidget(
        _app(
          MindHomeScreen(
            service: _FakeMind(
              status: const MindStatus.unavailable(
                MindUnavailable.modelsMissing,
                'Expected models in /tmp/airo_mind',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Models are not installed yet'), findsOneWidget);
      expect(find.textContaining('/tmp/airo_mind'), findsOneWidget);
      // Recording is not offered when it cannot work.
      expect(find.text('Record'), findsNothing);
    });

    testWidgets('a missing native library reads differently from missing models',
        (tester) async {
      await tester.pumpWidget(
        _app(
          MindHomeScreen(
            service: _FakeMind(
              status: const MindStatus.unavailable(
                MindUnavailable.bridgeMissing,
                'dlopen failed',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Airo Mind is not available on this platform'),
          findsOneWidget);
    });
  });

  group('search — step 7 of the journey', () {
    testWidgets('a hit shows the line that matched', (tester) async {
      final service = _FakeMind(
        library: [_meeting()],
        hits: [
          rust.SearchHit(
            meetingId: 'm1',
            title: 'Platform standup',
            recordedAt: BigInt.from(1700000000),
            snippet: 'Priya said the Kafka consumer lag is the bottleneck.',
          ),
        ],
      );
      await tester.pumpWidget(_app(MindHomeScreen(service: service)));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Kafka');
      await tester.pumpAndSettle();

      expect(service.searched, 'Kafka');
      expect(find.textContaining('Kafka consumer lag'), findsOneWidget);
    });

    testWidgets('no match says so rather than showing everything',
        (tester) async {
      await tester.pumpWidget(
        _app(MindHomeScreen(service: _FakeMind(library: [_meeting()]))),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'kubernetes');
      await tester.pumpAndSettle();

      expect(find.text('No meeting mentions that.'), findsOneWidget);
      expect(find.text('Platform standup'), findsNothing);
    });

    /// Clearing the box must restore the library, not leave an empty result
    /// list that looks like the meetings were lost.
    testWidgets('clearing the query brings the library back', (tester) async {
      await tester.pumpWidget(
        _app(MindHomeScreen(service: _FakeMind(library: [_meeting()]))),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'kubernetes');
      await tester.pumpAndSettle();
      expect(find.text('Platform standup'), findsNothing);

      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();
      expect(find.text('Platform standup'), findsOneWidget);
    });

    testWidgets('opening a hit opens the meeting — step 8', (tester) async {
      await tester.pumpWidget(
        _app(
          MindHomeScreen(
            service: _FakeMind(
              library: [_meeting()],
              hits: [
                rust.SearchHit(
                  meetingId: 'm1',
                  title: 'Platform standup',
                  recordedAt: BigInt.from(1700000000),
                  snippet: 'Priya said the Kafka consumer lag is the bottleneck.',
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Kafka');
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Kafka consumer lag'));
      await tester.pumpAndSettle();

      expect(find.text('Minutes'), findsOneWidget);
      expect(find.text('Transcript'), findsOneWidget);
    });
  });

  group('reading a meeting', () {
    testWidgets('shows minutes, transcript, and which model wrote them',
        (tester) async {
      await tester.pumpWidget(
        _app(
          MeetingScreen.stored(service: _FakeMind(), meeting: _meeting()),
        ),
      );
      await tester.pump();

      expect(find.text('- Add three pods before Friday'), findsOneWidget);
      expect(
        find.text('Priya said the Kafka consumer lag is the bottleneck.'),
        findsOneWidget,
      );
      // ADR-0018: a summary is a model's reading, and whose reading it was is
      // part of the record.
      expect(
        find.text('Minutes by qwen2.5-0.5b-instruct-q4_k_m'),
        findsOneWidget,
      );
    });
  });

  group('watching processing — step 3 of the journey', () {
    testWidgets('transcript then minutes appear as the models produce them',
        (tester) async {
      final controller = StreamController<MindProgress>();
      final service = _FakeMind(progress: controller.stream);

      await tester.pumpWidget(
        _app(
          MeetingScreen.live(
            service: service,
            title: 'Meeting 1',
            progress: controller.stream,
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Transcribing…'), findsOneWidget);

      controller.add(
        const MindProgress(
          stage: MindStage.transcribing,
          transcript: 'Priya said the lag is the bottleneck.',
        ),
      );
      await tester.pump();
      expect(find.text('Priya said the lag is the bottleneck.'), findsOneWidget);
      // Still running: the user can stop it.
      expect(find.text('Stop'), findsOneWidget);

      controller.add(
        const MindProgress(
          stage: MindStage.generating,
          transcript: 'Priya said the lag is the bottleneck.',
          minutes: '- Add three pods',
        ),
      );
      await tester.pump();
      expect(find.text('Writing minutes…'), findsOneWidget);
      expect(find.text('- Add three pods'), findsOneWidget);

      controller.add(
        const MindProgress(
          stage: MindStage.done,
          transcript: 'Priya said the lag is the bottleneck.',
          minutes: '- Add three pods',
          meetingId: 'm1',
        ),
      );
      await tester.pump();
      expect(find.text('Saved on this device'), findsOneWidget);
      expect(find.text('Stop'), findsNothing);

      await controller.close();
    });

    /// A failure that ends the stream silently looks exactly like a hang. The
    /// user must be told, on the screen they are already looking at.
    testWidgets('a failure is shown rather than ending the stream quietly',
        (tester) async {
      final controller = StreamController<MindProgress>();
      await tester.pumpWidget(
        _app(
          MeetingScreen.live(
            service: _FakeMind(),
            title: 'Meeting 1',
            progress: controller.stream,
          ),
        ),
      );
      await tester.pump();

      controller.add(
        const MindProgress(
          stage: MindStage.failed,
          error: 'No speech was found in the recording.',
        ),
      );
      await tester.pump();

      expect(find.text('Failed'), findsOneWidget);
      expect(
        find.text('No speech was found in the recording.'),
        findsOneWidget,
      );

      await controller.close();
    });

    testWidgets('Stop cancels the job rather than only leaving the screen',
        (tester) async {
      final controller = StreamController<MindProgress>();
      final service = _FakeMind();

      await tester.pumpWidget(
        _app(
          Navigator(
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (_) => MeetingScreen.live(
                service: service,
                title: 'Meeting 1',
                progress: controller.stream,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Stop'));
      await tester.pump();

      expect(
        service.cancelled,
        isTrue,
        reason: 'leaving the screen without cancelling leaves inference running',
      );
      await controller.close();
    });
  });
}
