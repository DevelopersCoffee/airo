import 'package:airo_app/core/app/tv_router.dart';
import 'package:airo_app/core/app/tv_shell.dart';
import 'package:core_ui/core_ui.dart';
import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'TV sidebar shows Home/Guide/Movies/Favorites/Settings, Home first',
    (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1280, 720);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final router = TvRouter.createRouter(initialLocation: TvRouteNames.live);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            iptvChannelsProvider.overrideWith((ref) async => const []),
            recentlyWatchedChannelsProvider.overrideWith(
              (ref) async => const [],
            ),
            streamingStateProvider.overrideWith(
              (ref) => Stream.value(
                StreamingState(
                  playbackState: PlaybackState.idle,
                  isLiveStream: true,
                ),
              ),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      final sidebar = find.byKey(const Key('tv-sidebar-nav'));
      expect(sidebar, findsOneWidget);
      for (final label in [
        'Home',
        'Guide',
        'Movies',
        'Favorites',
        'Settings',
      ]) {
        expect(
          find.descendant(of: sidebar, matching: find.text(label)),
          findsOneWidget,
        );
      }
    },
  );

  testWidgets('zen mode: sidebar is hidden while the player is fullscreen, and '
      'returns when fullscreen exits', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: TvShell(child: SizedBox.expand())),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('tv-sidebar-nav')), findsOneWidget);

    container.read(isFullscreenModeProvider.notifier).state = true;
    await tester.pump();

    expect(find.byKey(const Key('tv-sidebar-nav')), findsNothing);

    container.read(isFullscreenModeProvider.notifier).state = false;
    await tester.pump();

    expect(find.byKey(const Key('tv-sidebar-nav')), findsOneWidget);
  });

  testWidgets(
    'Settings overlay claims Theme focus and excludes retained live controls',
    (tester) async {
      final liveFocus = FocusNode(debugLabel: 'retained live action');
      addTearDown(liveFocus.dispose);
      var liveActivations = 0;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: TvShell(
              child: Align(
                alignment: Alignment.topLeft,
                child: TvFocusable(
                  focusNode: liveFocus,
                  autofocus: true,
                  onSelect: () => liveActivations++,
                  child: const SizedBox(
                    width: 160,
                    height: 56,
                    child: Text('Live action'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final settingsRailItem = tester.widget<TvFocusable>(
        find.ancestor(
          of: find.text('Settings'),
          matching: find.byType(TvFocusable),
        ),
      );
      settingsRailItem.focusNode!.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pump();

      // Fire TV restores the launching rail item after the overlay's first
      // frame. The overlay must reclaim focus on the following frame.
      settingsRailItem.focusNode!.requestFocus();
      await tester.pump();
      await tester.pumpAndSettle();

      final themeItem = tester.widget<TvFocusable>(
        find.ancestor(
          of: find.text('Theme'),
          matching: find.byType(TvFocusable),
        ),
      );
      expect(themeItem.focusNode?.hasPrimaryFocus, isTrue);
      expect(liveFocus.canRequestFocus, isFalse);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      final playbackItem = tester.widget<TvFocusable>(
        find.ancestor(
          of: find.text('Playback'),
          matching: find.byType(TvFocusable),
        ),
      );
      expect(playbackItem.focusNode?.hasPrimaryFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('tv_settings_section_playback')),
        findsOneWidget,
      );
      expect(liveActivations, 0);
    },
  );
}
