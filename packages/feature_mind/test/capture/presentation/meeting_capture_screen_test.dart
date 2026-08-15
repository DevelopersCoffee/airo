import 'package:feature_mind/src/capture/presentation/meeting_capture_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpScreen(WidgetTester tester) async {
    // Tall surface so consent + trust strip + controls fit without scrolling
    // (the trust strip (#1774) pushed the start button off a default phone
    // viewport and broke key lookups).
    await tester.binding.setSurfaceSize(const Size(400, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: MeetingCaptureScreen())),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'shows the explicit consent-reminder copy before anything else (AC6)',
    (tester) async {
      await pumpScreen(tester);

      expect(
        find.byKey(const Key('meeting_capture_consent_reminder_copy')),
        findsOneWidget,
      );
      expect(find.textContaining('checking it is on you'), findsOneWidget);
    },
  );

  testWidgets(
    'shows Multilingual · auto-detect badge and offline copy by default (#1774)',
    (tester) async {
      await pumpScreen(tester);

      expect(find.byKey(const Key('scribe_trust_signals')), findsOneWidget);
      expect(
        find.byKey(const Key('scribe_trust_language_badge')),
        findsOneWidget,
      );
      expect(find.text('Multilingual · auto-detect'), findsOneWidget);
      expect(find.text('On this device'), findsOneWidget);
      expect(
        find.byKey(const Key('scribe_trust_offline_copy')),
        findsOneWidget,
      );
      expect(
        find.textContaining('Sharing is always an explicit'),
        findsOneWidget,
      );
    },
  );

  testWidgets('start recording is disabled until consent is confirmed', (
    tester,
  ) async {
    await pumpScreen(tester);

    final startButton = tester.widget<FilledButton>(
      find.byKey(const Key('meeting_capture_start_button')),
    );
    expect(startButton.onPressed, isNull);
  });

  testWidgets(
    'a two-party jurisdiction blocks confirm until the notify-everyone box is checked',
    (tester) async {
      await pumpScreen(tester);

      await tester.tap(
        find.byKey(const Key('meeting_capture_jurisdiction_dropdown')),
      );
      await tester.pumpAndSettle();
      // California is a two-party consent jurisdiction.
      await tester.tap(find.text('United States — California').last);
      await tester.pumpAndSettle();

      final confirmButton = tester.widget<FilledButton>(
        find.byKey(const Key('meeting_capture_confirm_consent_button')),
      );
      expect(confirmButton.onPressed, isNull);

      await tester.tap(
        find.byKey(const Key('meeting_capture_all_parties_checkbox')),
      );
      await tester.pumpAndSettle();

      final confirmAfterAck = tester.widget<FilledButton>(
        find.byKey(const Key('meeting_capture_confirm_consent_button')),
      );
      expect(confirmAfterAck.onPressed, isNotNull);
    },
  );

  testWidgets('confirming consent unlocks the start-recording button', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.tap(
      find.byKey(const Key('meeting_capture_jurisdiction_dropdown')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('United States — California').last);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('meeting_capture_all_parties_checkbox')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('meeting_capture_confirm_consent_button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('meeting_capture_consent_granted')),
      findsOneWidget,
    );
    final startButton = tester.widget<FilledButton>(
      find.byKey(const Key('meeting_capture_start_button')),
    );
    expect(startButton.onPressed, isNotNull);
  });

  testWidgets(
    'a one-party jurisdiction confirms without the notify-everyone box',
    (tester) async {
      await pumpScreen(tester);

      await tester.tap(
        find.byKey(const Key('meeting_capture_jurisdiction_dropdown')),
      );
      await tester.pumpAndSettle();
      // United Kingdom is a one-party consent jurisdiction -- no checkbox
      // should even appear. It's low in a long dropdown list, so scroll it
      // into view first (the menu is a lazily-built ListView, so it isn't in
      // the tree at all until scrolled close enough to build).
      await tester.scrollUntilVisible(
        find.text('United Kingdom'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('United Kingdom'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('meeting_capture_all_parties_checkbox')),
        findsNothing,
      );
      final confirmButton = tester.widget<FilledButton>(
        find.byKey(const Key('meeting_capture_confirm_consent_button')),
      );
      expect(confirmButton.onPressed, isNotNull);
    },
  );
}
