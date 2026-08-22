import 'package:feature_mind/src/capture/domain/speaker_activity_span.dart';
import 'package:feature_mind/src/capture/presentation/speaker_activity_timeline.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders speaker lanes for provisional spans', (tester) async {
    final spans = [
      const SpeakerActivitySpan(
        speakerIndex: 0,
        startMs: 0,
        endMs: 4000,
      ),
      const SpeakerActivitySpan(
        speakerIndex: 1,
        startMs: 5000,
        endMs: 8000,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SpeakerActivityTimeline(
            spans: spans,
            timelineEndMs: 10000,
            activeSpeakerIndex: 1,
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('meeting_capture_speaker_activity')), findsOneWidget);
    expect(find.text('Speaker 1'), findsOneWidget);
    expect(find.text('Speaker 2'), findsOneWidget);
    expect(find.byKey(const Key('speaker_lane_label_1')), findsOneWidget);
  });

  testWidgets('hides when there are no spans and no active speaker', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SpeakerActivityTimeline(
            spans: const [],
            timelineEndMs: 0,
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('meeting_capture_speaker_activity')), findsNothing);
  });
}
