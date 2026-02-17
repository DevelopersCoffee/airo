import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:airo_app/features/iptv/domain/models/streaming_state.dart';
import 'package:airo_app/features/iptv/presentation/widgets/go_live_button.dart';

void main() {
  group('GoLiveButton', () {
    testWidgets('should not render when shouldShowGoLive is false',
        (tester) async {
      // State at live edge, playing - should not show button
      final state = const StreamingState().copyWith(
        isLiveStream: true,
        liveDelay: const Duration(seconds: 1),
        playbackState: PlaybackState.playing,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GoLiveButton(
              state: state,
              onGoLive: () {},
            ),
          ),
        ),
      );

      // Button should not be visible (SizedBox.shrink)
      expect(find.text('Go Live'), findsNothing);
    });

    testWidgets('should render when behind live', (tester) async {
      final state = const StreamingState().copyWith(
        isLiveStream: true,
        liveDelay: const Duration(seconds: 15),
        playbackState: PlaybackState.playing,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GoLiveButton(
              state: state,
              onGoLive: () {},
            ),
          ),
        ),
      );

      expect(find.text('Go Live'), findsOneWidget);
    });

    testWidgets('should render when paused', (tester) async {
      final state = const StreamingState().copyWith(
        isLiveStream: true,
        liveDelay: const Duration(seconds: 2),
        playbackState: PlaybackState.paused,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GoLiveButton(
              state: state,
              onGoLive: () {},
            ),
          ),
        ),
      );

      expect(find.text('Go Live'), findsOneWidget);
    });

    testWidgets('should trigger onGoLive callback when tapped',
        (tester) async {
      bool callbackTriggered = false;
      final state = const StreamingState().copyWith(
        isLiveStream: true,
        liveDelay: const Duration(seconds: 15),
        playbackState: PlaybackState.playing,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GoLiveButton(
              state: state,
              onGoLive: () {
                callbackTriggered = true;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byType(GoLiveButton));
      await tester.pumpAndSettle();

      expect(callbackTriggered, isTrue);
    });

    testWidgets('should not trigger callback when disabled', (tester) async {
      bool callbackTriggered = false;
      final state = const StreamingState().copyWith(
        isLiveStream: true,
        liveDelay: const Duration(seconds: 15),
        playbackState: PlaybackState.playing,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GoLiveButton(
              state: state,
              onGoLive: () {
                callbackTriggered = true;
              },
              enabled: false,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(GoLiveButton));
      await tester.pumpAndSettle();

      expect(callbackTriggered, isFalse);
    });

    testWidgets('compact variant should render smaller', (tester) async {
      final state = const StreamingState().copyWith(
        isLiveStream: true,
        liveDelay: const Duration(seconds: 15),
        playbackState: PlaybackState.playing,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GoLiveButton(
              state: state,
              onGoLive: () {},
              compact: true,
            ),
          ),
        ),
      );

      // Compact version uses icon, not text
      expect(find.text('Go Live'), findsNothing);
      expect(find.byType(GoLiveButton), findsOneWidget);
    });
  });
}

