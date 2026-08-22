import 'package:feature_mind/src/capture/presentation/audio_amplitude_meter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders amplitude bars from recent samples', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AudioAmplitudeMeter(
            samples: [0.1, 0.3, 0.5, 0.8],
            isPaused: false,
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('meeting_capture_amplitude_meter')), findsOneWidget);
  });

  testWidgets('shows flat bars when paused', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AudioAmplitudeMeter(
            samples: [0.9, 0.9, 0.9],
            isPaused: true,
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('meeting_capture_amplitude_meter')), findsOneWidget);
  });
}
