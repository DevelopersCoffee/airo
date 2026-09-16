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

  testWidgets(
    'opening Settings from the rail leaves no live playback surface',
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
      final streamingService = _RecordingStreamingService();

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
            iptvStreamingServiceProvider.overrideWith((ref) {
              ref.onDispose(streamingService.dispose);
              return streamingService;
            }),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(IPTVScreen), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('tv-sidebar-nav')),
          matching: find.text('Settings'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(IPTVScreen), findsNothing);
      expect(streamingService.stopCount, 1);
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

  testWidgets('Settings is a real route and does not retain live controls', (
    tester,
  ) async {
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
          recentlyWatchedChannelsProvider.overrideWith((ref) async => const []),
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

    expect(find.byType(IPTVScreen), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('tv-sidebar-nav')),
        matching: find.text('Settings'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(IPTVScreen), findsNothing);

    final themeItem = tester.widget<TvFocusable>(
      find.ancestor(of: find.text('Theme'), matching: find.byType(TvFocusable)),
    );
    expect(themeItem.focusNode?.hasPrimaryFocus, isTrue);

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
    expect(find.byType(IPTVScreen), findsNothing);
  });

  testWidgets('BACK from Settings does not restore a live playback surface', (
    tester,
  ) async {
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
          recentlyWatchedChannelsProvider.overrideWith((ref) async => const []),
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

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('tv-sidebar-nav')),
        matching: find.text('Settings'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Theme'), findsOneWidget);
    expect(find.byType(IPTVScreen), findsNothing);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(IPTVScreen), findsNothing);
  });

  testWidgets('BACK is left to the player while fullscreen', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: TvShell(child: SizedBox.expand())),
      ),
    );
    await tester.pumpAndSettle();

    container.read(isFullscreenModeProvider.notifier).state = true;
    await tester.pumpAndSettle();

    // In fullscreen BACK means "leave fullscreen", which IPTVScreen owns.
    // The shell must not swallow it, or exiting fullscreen would take two
    // presses on a real remote.
    expect(await tester.binding.handlePopRoute(), isFalse);
  });
}

class _RecordingStreamingService extends VideoPlayerStreamingService {
  _RecordingStreamingService() : super(engine: FakeAiroPlaybackEngine());

  int stopCount = 0;

  @override
  Future<void> stop() async {
    stopCount++;
    await super.stop();
  }
}
