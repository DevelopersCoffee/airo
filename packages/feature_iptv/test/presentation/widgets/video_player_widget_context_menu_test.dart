import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Player MENU owns Player actions. The separate channel-actions overlay stays
// reachable through Fire TV's long-press Select convention and the transport
// bar's Info button.
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
            body: SizedBox(width: 960, height: 540, child: VideoPlayerWidget()),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    return container;
  }

  Future<void> openContextMenu(WidgetTester tester) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
    await tester.pump();
    expect(find.text('Actions for'), findsOneWidget);
  }

  testWidgets('MENU key opens Player actions for the current stream', (
    tester,
  ) async {
    await pumpPlayer(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Player actions'), findsOneWidget);
    expect(find.text('Actions for'), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('selecting Add to favorites toggles the favorite and closes '
      'the menu', (tester) async {
    final container = await pumpPlayer(tester);

    await openContextMenu(tester);

    await tester.tap(find.text('Add to favorites'));
    await tester.pump();
    await tester.pump();

    final ids = await container.read(favoriteChannelIdsProvider.future);
    expect(ids, contains('news-1'));
    expect(find.text('Actions for'), findsNothing);
    expect(find.text('City News Live added to favorites'), findsOneWidget);
  });

  testWidgets('Fire OS BACK pair closes the context menu without navigating', (
    tester,
  ) async {
    await pumpPlayer(tester);

    await openContextMenu(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.text('Actions for'), findsOneWidget);

    final handled = await tester.binding.handlePopRoute();
    await tester.pump();

    expect(handled, isTrue);
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

      await openContextMenu(tester);

      final handled = await tester.binding.handlePopRoute();

      expect(
        handled,
        isTrue,
        reason:
            'PopScope must report the back request as handled, or the '
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

  testWidgets(
    'channel actions visibly own focus, trap DOWN, and restore player focus',
    (tester) async {
      await pumpPlayer(tester);
      await openContextMenu(tester);

      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'channel action Favorite',
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      final refreshFocus = tester.widget<Focus>(
        find
            .descendant(
              of: find.byKey(const ValueKey('context-menu-refresh-playlist')),
              matching: find.byType(Focus),
            )
            .first,
      );
      expect(refreshFocus.focusNode?.hasPrimaryFocus, isTrue);
      expect(find.text('Mini guide'), findsNothing);
      expect(find.text('Recent channels'), findsNothing);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.text('Actions for'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text('Actions for'), findsNothing);
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'player center control',
      );
    },
  );

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

  // Regression for issues/01-remote-focus-contract.md acceptance criterion
  // 5: "Holding Select does not also trigger the short-press action."
  // TvInputHandler fires on every key-down, so before this fix the
  // short-press reveal-controls action (which moves focus onto the center
  // play/pause control) ran on Select's down-stroke regardless of how long
  // it was then held -- doubling up with the context menu that opened 500ms
  // later on the same press.
  testWidgets('a short Select tap moves focus onto the center control', (
    tester,
  ) async {
    await pumpPlayer(tester);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
    await tester.pump();

    expect(find.text('Actions for'), findsNothing);
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'player center control',
    );
  });

  testWidgets(
    'a long-press does not also move focus onto the center control -- only '
    'the context menu opens',
    (tester) async {
      await pumpPlayer(tester);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
      await tester.pump();

      expect(find.text('Actions for'), findsOneWidget);
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        isNot('player center control'),
        reason:
            'the long-press must not also fire the short-press reveal '
            'action on top of opening the context menu',
      );
    },
  );
}
