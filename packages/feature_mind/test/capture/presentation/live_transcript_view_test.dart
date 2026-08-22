import 'package:feature_mind/src/capture/domain/live_transcript_line.dart';
import 'package:feature_mind/src/capture/presentation/live_transcript_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders speaker bullet rows and partial cursor', (tester) async {
    final lines = [
      const LiveTranscriptLine(
        segmentId: 's0',
        speakerLabel: 'Speaker 1',
        text: 'We need to finish the migration',
        startMs: 5000,
        isPartial: false,
      ),
      const LiveTranscriptLine(
        segmentId: 'partial',
        speakerLabel: 'Speaker 2',
        text: 'Okay I will take',
        startMs: 12000,
        isPartial: true,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LiveTranscriptView(
            lines: lines,
            followLive: true,
            onFollowLiveChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('meeting_capture_live_transcript')), findsOneWidget);
    expect(find.text('Speaker 1'), findsOneWidget);
    expect(find.text('Speaker 2'), findsOneWidget);
    expect(find.textContaining('We need to finish'), findsOneWidget);
    expect(find.textContaining('Okay I will take ▌'), findsOneWidget);
    expect(find.byIcon(Icons.circle), findsNWidgets(2));
  });

  testWidgets('shows listening placeholder when empty', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LiveTranscriptView(
            lines: const [],
            followLive: true,
            onFollowLiveChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('meeting_capture_live_listening')), findsOneWidget);
  });
}
