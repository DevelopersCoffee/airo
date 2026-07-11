import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import "package:feature_iptv/feature_iptv.dart";
import "package:platform_channels/platform_channels.dart";

void main() {
  group('LiveBadge', () {
    testWidgets('should not render when not a live stream', (tester) async {
      const state = StreamingState(); // Default is not live

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: LiveBadge(state: state)),
        ),
      );

      expect(find.text('LIVE'), findsNothing);
    });

    testWidgets('should render LIVE text when at live edge', (tester) async {
      final state = const StreamingState().copyWith(
        isLiveStream: true,
        liveDelay: const Duration(seconds: 1),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: LiveBadge(state: state)),
        ),
      );

      expect(find.text('LIVE'), findsOneWidget);
    });

    testWidgets('should render when behind live with showWhenNotLive=true', (
      tester,
    ) async {
      final state = const StreamingState().copyWith(
        isLiveStream: true,
        liveDelay: const Duration(seconds: 30),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: LiveBadge(state: state, showWhenNotLive: true)),
        ),
      );

      expect(find.text('LIVE'), findsOneWidget);
    });

    testWidgets(
      'should not render when behind live with showWhenNotLive=false',
      (tester) async {
        final state = const StreamingState().copyWith(
          isLiveStream: true,
          liveDelay: const Duration(seconds: 30),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: LiveBadge(state: state, showWhenNotLive: false),
            ),
          ),
        );

        expect(find.text('LIVE'), findsNothing);
      },
    );
  });

  group('DelayIndicator', () {
    testWidgets('should not render when not behind live', (tester) async {
      final state = const StreamingState().copyWith(
        isLiveStream: true,
        liveDelay: const Duration(seconds: 2),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: DelayIndicator(state: state)),
        ),
      );

      expect(find.textContaining('behind'), findsNothing);
    });

    testWidgets('should render delay when behind live', (tester) async {
      final state = const StreamingState().copyWith(
        isLiveStream: true,
        liveDelay: const Duration(seconds: 45),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: DelayIndicator(state: state)),
        ),
      );

      expect(find.text('45s behind'), findsOneWidget);
    });

    testWidgets('should render minutes format for large delays', (
      tester,
    ) async {
      final state = const StreamingState().copyWith(
        isLiveStream: true,
        liveDelay: const Duration(minutes: 2, seconds: 15),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: DelayIndicator(state: state)),
        ),
      );

      expect(find.text('2m 15s behind'), findsOneWidget);
    });

    testWidgets('should apply custom text style', (tester) async {
      final state = const StreamingState().copyWith(
        isLiveStream: true,
        liveDelay: const Duration(seconds: 30),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DelayIndicator(
              state: state,
              style: const TextStyle(fontSize: 20, color: Colors.red),
            ),
          ),
        ),
      );

      final textWidget = tester.widget<Text>(find.text('30s behind'));
      expect(textWidget.style?.fontSize, equals(20));
      expect(textWidget.style?.color, equals(Colors.red));
    });
  });
}
