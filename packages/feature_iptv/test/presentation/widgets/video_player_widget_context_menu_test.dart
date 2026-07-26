import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// AiroTV D-pad design's "CONTEXT MENU (MENU key)" screen — reachable from
// the live player via the remote's MENU key, previously entirely unhandled
// (TvInputKey.menu fell through to the switch's default case).
void main() {
  Future<ProviderContainer> pumpPlayer(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        streamingStateProvider.overrideWith(
          (ref) => Stream.value(
            StreamingState(
              playbackState: PlaybackState.playing,
              isLiveStream: true,
              currentChannel: IPTVChannel(
                id: 'news-1',
                name: 'City News Live',
                streamUrl: 'https://example.com/news.m3u8',
                group: 'News',
              ),
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 960,
              height: 540,
              child: VideoPlayerWidget(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    return container;
  }

  testWidgets('MENU key opens the context menu for the current channel', (
    tester,
  ) async {
    await pumpPlayer(tester);

    expect(find.text('Actions for'), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
    await tester.pump();

    expect(find.text('Actions for'), findsOneWidget);
    expect(find.text('City News Live'), findsWidgets);
    expect(find.text('Add to favorites'), findsOneWidget);
  });

  testWidgets('selecting Add to favorites toggles the favorite and closes '
      'the menu', (tester) async {
    final container = await pumpPlayer(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
    await tester.pump();

    await tester.tap(find.text('Add to favorites'));
    await tester.pump();
    await tester.pump();

    final ids = await container.read(favoriteChannelIdsProvider.future);
    expect(ids, contains('news-1'));
    expect(find.text('Actions for'), findsNothing);
    expect(find.text('City News Live added to favorites'), findsOneWidget);
  });

  testWidgets('BACK closes the context menu without navigating away', (
    tester,
  ) async {
    await pumpPlayer(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
    await tester.pump();
    expect(find.text('Actions for'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(find.text('Actions for'), findsNothing);
  });

  // Confirmed on a real Fire TV Stick: TvInputHandler observes the BACK key
  // via a passive KeyboardListener, which cannot consume the platform back
  // button. tester.sendKeyEvent(escape) above only proves the in-app state
  // closes -- it doesn't touch the Navigator's real pop path, so it missed
  // this. The real Android back button was reaching the Activity handler
  // *at the same time* as our state update and exiting the app. PopScope
  // is what actually intercepts a platform pop request; simulate that
  // directly via handlePopRoute (what a real Android back button drives).
  testWidgets(
    'a real platform back request is consumed while the context menu is '
    'open, instead of also popping the app',
    (tester) async {
      await pumpPlayer(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
      await tester.pump();
      expect(find.text('Actions for'), findsOneWidget);

      final handled = await tester.binding.handlePopRoute();

      expect(
        handled,
        isTrue,
        reason: 'PopScope must report the back request as handled, or the '
            'platform (Android) proceeds to pop/exit the Activity on top '
            "of whatever the app's own state did.",
      );
      await tester.pump();
      expect(find.text('Actions for'), findsNothing);
    },
  );

  // Confirmed via on-device logcat: Fire OS intercepts KEYCODE_MENU for its
  // own system overlay before Flutter's embedding ever sees it, so
  // TvInputKey.menu is unreachable on real Fire TV hardware. Long-press
  // Select/OK is the Fire TV convention (Prime Video, Netflix) and does
  // reach the app.
  testWidgets('long-pressing Select opens the context menu', (tester) async {
    await pumpPlayer(tester);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Actions for'), findsNothing);

    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Actions for'), findsOneWidget);

    await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
    await tester.pump();
  });

  testWidgets('a short Select tap does not open the context menu', (
    tester,
  ) async {
    await pumpPlayer(tester);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Actions for'), findsNothing);
  });
}
