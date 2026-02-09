import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:airo_app/features/media_hub/presentation/widgets/media_mode_switch.dart';
import 'package:airo_app/features/media_hub/application/providers/media_hub_providers.dart';
import 'package:airo_app/features/media_hub/domain/models/media_mode.dart';

void main() {
  group('MediaModeSwitch', () {
    Widget createTestWidget({
      MediaMode initialMode = MediaMode.music,
      void Function(MediaMode)? onModeChanged,
    }) {
      return ProviderScope(
        overrides: [
          selectedMediaModeProvider.overrideWith((ref) => initialMode),
        ],
        child: MaterialApp(
          home: Scaffold(body: MediaModeSwitch(onModeChanged: onModeChanged)),
        ),
      );
    }

    testWidgets('renders with Music and TV options', (tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('Music'), findsOneWidget);
      expect(find.text('TV'), findsOneWidget);
      expect(find.byIcon(Icons.music_note), findsOneWidget);
      expect(find.byIcon(Icons.live_tv), findsOneWidget);
    });

    testWidgets('starts with Music selected by default', (tester) async {
      await tester.pumpWidget(createTestWidget());

      // The Music button should be styled as selected
      final musicText = tester.widget<Text>(find.text('Music'));
      expect(musicText.style?.fontWeight, FontWeight.bold);
    });

    testWidgets('starts with TV selected when initialMode is tv', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget(initialMode: MediaMode.tv));

      // The TV button should be styled as selected
      final tvText = tester.widget<Text>(find.text('TV'));
      expect(tvText.style?.fontWeight, FontWeight.bold);
    });

    testWidgets('switches to TV mode when TV is tapped', (tester) async {
      MediaMode? changedMode;
      await tester.pumpWidget(
        createTestWidget(onModeChanged: (mode) => changedMode = mode),
      );

      // Tap TV button
      await tester.tap(find.text('TV'));
      await tester.pumpAndSettle();

      expect(changedMode, MediaMode.tv);
    });

    testWidgets('switches to Music mode when Music is tapped from TV', (
      tester,
    ) async {
      MediaMode? changedMode;
      await tester.pumpWidget(
        createTestWidget(
          initialMode: MediaMode.tv,
          onModeChanged: (mode) => changedMode = mode,
        ),
      );

      // Tap Music button
      await tester.tap(find.text('Music'));
      await tester.pumpAndSettle();

      expect(changedMode, MediaMode.music);
    });

    testWidgets('does not call callback when same mode is tapped', (
      tester,
    ) async {
      int callCount = 0;
      await tester.pumpWidget(
        createTestWidget(onModeChanged: (mode) => callCount++),
      );

      // Tap Music button (already selected)
      await tester.tap(find.text('Music'));
      await tester.pumpAndSettle();

      expect(callCount, 0);
    });

    testWidgets('animates indicator on mode change', (tester) async {
      await tester.pumpWidget(createTestWidget());

      // Tap TV button
      await tester.tap(find.text('TV'));

      // Pump partially through animation
      await tester.pump(const Duration(milliseconds: 150));

      // Animation should be in progress
      await tester.pump(const Duration(milliseconds: 150));

      // Animation should complete
      await tester.pumpAndSettle();
    });

    testWidgets('has correct height', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(body: const MediaModeSwitch(height: 56.0)),
          ),
        ),
      );

      final container = tester.widget<Container>(find.byType(Container).first);
      final constraints = container.constraints;
      expect(constraints?.maxHeight, 56.0);
    });

    testWidgets('updates provider state on mode change', (tester) async {
      late ProviderContainer container;
      await tester.pumpWidget(
        ProviderScope(
          child: Builder(
            builder: (context) {
              container = ProviderScope.containerOf(context);
              return MaterialApp(home: Scaffold(body: const MediaModeSwitch()));
            },
          ),
        ),
      );

      // Initially Music
      expect(container.read(selectedMediaModeProvider), MediaMode.music);

      // Tap TV
      await tester.tap(find.text('TV'));
      await tester.pumpAndSettle();

      // Should be TV now
      expect(container.read(selectedMediaModeProvider), MediaMode.tv);
    });

    testWidgets('is accessible with icons having semantic labels', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget());

      // Find the icons with semantic labels
      final musicIcon = find.byWidgetPredicate(
        (widget) => widget is Icon && widget.semanticLabel == 'Music mode',
      );
      final tvIcon = find.byWidgetPredicate(
        (widget) => widget is Icon && widget.semanticLabel == 'TV mode',
      );

      expect(musicIcon, findsOneWidget);
      expect(tvIcon, findsOneWidget);
    });
  });
}
