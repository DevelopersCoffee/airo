import 'dart:async';
import 'dart:io';

import 'package:airo_app/core/app/tv_router.dart';
import 'package:airo_app/core/app/tv_shell.dart';
import 'package:core_ui/core_ui.dart';
import 'package:feature_iptv/application/providers/tv_playlist_pairing_provider.dart';
import 'package:feature_iptv/application/services/tv_playlist_pairing_server.dart';
import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Finder _tvSidebar() => find.byKey(const Key('tv-sidebar-nav'));

Finder _tvSidebarIcon(IconData icon) =>
    find.descendant(of: _tvSidebar(), matching: find.byIcon(icon));

void _setTenFootView(WidgetTester tester, {Size size = const Size(1280, 720)}) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

bool _railDestinationHasPrimaryFocus() {
  final label = FocusManager.instance.primaryFocus?.debugLabel ?? '';
  return label.contains('TV rail');
}

bool _focusIsInSidebar(WidgetTester tester) {
  final focusContext = FocusManager.instance.primaryFocus?.context;
  if (focusContext == null) return false;
  final focusedRender = focusContext.findRenderObject();
  final sidebarRender = tester.renderObject(_tvSidebar());
  var node = focusedRender;
  while (node != null) {
    if (identical(node, sidebarRender)) return true;
    node = node.parent;
  }
  return false;
}

Future<void> _pumpTvShellWithContent(
  WidgetTester tester, {
  required Widget child,
}) async {
  _setTenFootView(tester);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(home: TvShell(child: child)),
    ),
  );
  await tester.pumpAndSettle();
}

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
            tvPlaylistPairingServerFactoryProvider.overrideWithValue(
              () => _FakePairingServer(never: true),
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

      expect(_tvSidebar(), findsOneWidget);
      expect(_tvSidebarIcon(Icons.home), findsOneWidget);
      expect(_tvSidebarIcon(Icons.grid_view_outlined), findsOneWidget);
      expect(_tvSidebarIcon(Icons.movie_outlined), findsOneWidget);
      expect(_tvSidebarIcon(Icons.favorite_border), findsOneWidget);
      expect(_tvSidebarIcon(Icons.settings_outlined), findsOneWidget);
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
            tvPlaylistPairingServerFactoryProvider.overrideWithValue(
              () => _FakePairingServer(never: true),
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

      await tester.tap(_tvSidebarIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();

      expect(find.byType(IPTVScreen), findsNothing);
      expect(streamingService.stopCount, 1);
    },
  );

  testWidgets(
    'opening Settings from Watch awaits stop before leaving /player',
    (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1280, 720);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final router = TvRouter.createRouter(
        initialLocation: TvRouteNames.player,
      );
      final stopHold = Completer<void>();
      final streamingService = _RecordingStreamingService(stopHold: stopHold);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            iptvChannelsProvider.overrideWith((ref) async => const []),
            recentlyWatchedChannelsProvider.overrideWith(
              (ref) async => const [],
            ),
            tvPlaylistPairingServerFactoryProvider.overrideWithValue(
              () => _FakePairingServer(never: true),
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

      await tester.tap(_tvSidebarIcon(Icons.settings_outlined));
      await tester.pump();

      expect(
        find.byType(IPTVScreen),
        findsOneWidget,
        reason: 'Watch must stay mounted until stop() completes',
      );
      expect(streamingService.stopCount, 1);

      stopHold.complete();
      await tester.pumpAndSettle();

      expect(find.byType(IPTVScreen), findsNothing);
      expect(streamingService.stopCount, 1);
    },
  );

  testWidgets('non-fullscreen Back from Watch awaits stop and lands on Home', (
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
    final router = TvRouter.createRouter(initialLocation: TvRouteNames.player);
    final stopHold = Completer<void>();
    final streamingService = _RecordingStreamingService(stopHold: stopHold);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          iptvChannelsProvider.overrideWith((ref) async => const []),
          recentlyWatchedChannelsProvider.overrideWith((ref) async => const []),
          tvPlaylistPairingServerFactoryProvider.overrideWithValue(
            () => _FakePairingServer(never: true),
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

    await tester.binding.handlePopRoute();
    await tester.pump();

    expect(
      find.byType(IPTVScreen),
      findsOneWidget,
      reason: 'Back must await stop() before leaving Watch',
    );
    expect(streamingService.stopCount, 1);

    stopHold.complete();
    await tester.pumpAndSettle();

    expect(find.byType(IPTVScreen), findsNothing);
    expect(find.text('Your media. Your player.'), findsOneWidget);
    expect(find.textContaining('same Wi-Fi'), findsOneWidget);
    expect(streamingService.stopCount, 1);
  });

  testWidgets('fullscreen Back from Watch does not stop playback or go Home', (
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
    final router = TvRouter.createRouter(initialLocation: TvRouteNames.player);
    final streamingService = _RecordingStreamingService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          iptvChannelsProvider.overrideWith((ref) async => const []),
          recentlyWatchedChannelsProvider.overrideWith((ref) async => const []),
          tvPlaylistPairingServerFactoryProvider.overrideWithValue(
            () => _FakePairingServer(never: true),
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

    final container = ProviderScope.containerOf(
      tester.element(find.byType(IPTVScreen)),
    );
    container.read(isFullscreenModeProvider.notifier).state = true;
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(IPTVScreen), findsOneWidget);
    expect(find.text('Your media. Your player.'), findsNothing);
    expect(streamingService.stopCount, 0);
  });

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
          tvPlaylistPairingServerFactoryProvider.overrideWithValue(
            () => _FakePairingServer(never: true),
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

    expect(find.byType(IPTVScreen), findsOneWidget);

    await tester.tap(_tvSidebarIcon(Icons.settings_outlined));
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

  testWidgets('BACK from Settings lands on Home and does not exit the app', (
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
    final router = TvRouter.createRouter(
      initialLocation: TvRouteNames.settings,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          iptvChannelsProvider.overrideWith((ref) async => const []),
          recentlyWatchedChannelsProvider.overrideWith((ref) async => const []),
          tvPlaylistPairingServerFactoryProvider.overrideWithValue(
            () => _FakePairingServer(never: true),
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

    expect(find.text('Theme'), findsOneWidget);

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();

    expect(find.text('Your media. Your player.'), findsOneWidget);
    expect(find.textContaining('same Wi-Fi'), findsOneWidget);
    expect(find.byType(IPTVScreen), findsNothing);
  });

  testWidgets('BACK from Guide lands on Home and does not exit the app', (
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
    final router = TvRouter.createRouter(initialLocation: TvRouteNames.guide);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          iptvChannelsProvider.overrideWith((ref) async => const []),
          recentlyWatchedChannelsProvider.overrideWith((ref) async => const []),
          tvPlaylistPairingServerFactoryProvider.overrideWithValue(
            () => _FakePairingServer(never: true),
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

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();

    expect(find.text('Your media. Your player.'), findsOneWidget);
    expect(find.textContaining('same Wi-Fi'), findsOneWidget);
    expect(find.byType(IPTVScreen), findsNothing);
  });

  testWidgets('moving from /live to /player does not stop the Watch session', (
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
    final streamingService = _RecordingStreamingService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          iptvChannelsProvider.overrideWith((ref) async => const []),
          recentlyWatchedChannelsProvider.overrideWith((ref) async => const []),
          tvPlaylistPairingServerFactoryProvider.overrideWithValue(
            () => _FakePairingServer(never: true),
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
    expect(streamingService.stopCount, 0);

    router.go(TvRouteNames.player);
    await tester.pumpAndSettle();

    expect(find.byType(IPTVScreen), findsOneWidget);
    expect(streamingService.stopCount, 0);
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

  testWidgets(
    'LEFT from the first content item focuses the current rail destination',
    (tester) async {
      final contentFocus = FocusNode(debugLabel: 'leading-content');
      addTearDown(contentFocus.dispose);

      await _pumpTvShellWithContent(
        tester,
        child: Align(
          alignment: Alignment.centerLeft,
          child: TvFocusable(
            focusNode: contentFocus,
            autofocus: true,
            onSelect: () {},
            child: const SizedBox(
              width: 120,
              height: 56,
              child: Text('First card'),
            ),
          ),
        ),
      );

      expect(contentFocus.hasPrimaryFocus, isTrue);
      expect(_railDestinationHasPrimaryFocus(), isFalse);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();

      expect(contentFocus.hasPrimaryFocus, isFalse);
      expect(_railDestinationHasPrimaryFocus(), isTrue);
      expect(FocusManager.instance.primaryFocus?.debugLabel, contains('Home'));
    },
  );

  testWidgets('RIGHT from the rail restores the last content focus', (
    tester,
  ) async {
    final topFocus = FocusNode(debugLabel: 'top-card');
    final bottomFocus = FocusNode(debugLabel: 'bottom-card');
    addTearDown(topFocus.dispose);
    addTearDown(bottomFocus.dispose);

    await _pumpTvShellWithContent(
      tester,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TvFocusable(
            focusNode: topFocus,
            onSelect: () {},
            child: const SizedBox(width: 120, height: 56, child: Text('Top')),
          ),
          TvFocusable(
            focusNode: bottomFocus,
            autofocus: true,
            onSelect: () {},
            child: const SizedBox(
              width: 120,
              height: 56,
              child: Text('Bottom'),
            ),
          ),
        ],
      ),
    );

    expect(bottomFocus.hasPrimaryFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(_railDestinationHasPrimaryFocus(), isTrue);
    expect(bottomFocus.hasPrimaryFocus, isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();

    expect(bottomFocus.hasPrimaryFocus, isTrue);
    expect(topFocus.hasPrimaryFocus, isFalse);
    expect(_railDestinationHasPrimaryFocus(), isFalse);
  });

  testWidgets('BACK from Home does not focus the rail', (tester) async {
    _setTenFootView(tester);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final router = TvRouter.createRouter(initialLocation: TvRouteNames.home);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          iptvChannelsProvider.overrideWith((ref) async => const []),
          recentlyWatchedChannelsProvider.overrideWith((ref) async => const []),
          tvPlaylistPairingServerFactoryProvider.overrideWithValue(
            () => _FakePairingServer(never: true),
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

    expect(find.text('Your media. Your player.'), findsOneWidget);
    expect(find.textContaining('same Wi-Fi'), findsOneWidget);
    expect(_focusIsInSidebar(tester), isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(_focusIsInSidebar(tester), isFalse);
    expect(_railDestinationHasPrimaryFocus(), isFalse);
    expect(find.text('Your media. Your player.'), findsOneWidget);
    expect(await tester.binding.handlePopRoute(), isFalse);
  });

  testWidgets(
    'rail is ~80 collapsed and ~240 expanded with labels only when focused',
    (tester) async {
      final contentFocus = FocusNode(debugLabel: 'leading-content');
      addTearDown(contentFocus.dispose);

      await _pumpTvShellWithContent(
        tester,
        child: Align(
          alignment: Alignment.centerLeft,
          child: TvFocusable(
            focusNode: contentFocus,
            autofocus: true,
            onSelect: () {},
            child: const SizedBox(
              width: 120,
              height: 56,
              child: Text('First card'),
            ),
          ),
        ),
      );

      expect(contentFocus.hasPrimaryFocus, isTrue);
      expect(tester.getSize(_tvSidebar()).width, closeTo(80, 4));
      expect(
        find.descendant(of: _tvSidebar(), matching: find.text('Home')),
        findsNothing,
      );
      expect(
        find.descendant(of: _tvSidebar(), matching: find.text('Aika Stream')),
        findsNothing,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();

      expect(_railDestinationHasPrimaryFocus(), isTrue);
      expect(tester.getSize(_tvSidebar()).width, closeTo(240, 8));
      expect(
        find.descendant(of: _tvSidebar(), matching: find.text('Aika Stream')),
        findsOneWidget,
      );
      expect(find.text('Airo TV'), findsNothing);
      expect(find.text('AIRO TV'), findsNothing);
      expect(find.text('Midas Stream'), findsNothing);
      for (final label in [
        'Home',
        'Guide',
        'Movies',
        'Favorites',
        'Settings',
      ]) {
        expect(
          find.descendant(of: _tvSidebar(), matching: find.text(label)),
          findsOneWidget,
        );
      }
    },
  );

  testWidgets(
    'Home QR landing chrome is Aika Stream, not Airo TV or Midas Stream',
    (tester) async {
      _setTenFootView(tester);

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final router = TvRouter.createRouter(initialLocation: TvRouteNames.home);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            iptvChannelsProvider.overrideWith((ref) async => const []),
            recentlyWatchedChannelsProvider.overrideWith(
              (ref) async => const [],
            ),
            tvPlaylistPairingServerFactoryProvider.overrideWithValue(
              () => _FakePairingServer(never: true),
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

      expect(find.text(TvStoreProduct.displayName), findsWidgets);
      expect(find.text('Your media. Your player.'), findsOneWidget);
      expect(find.textContaining('same Wi-Fi'), findsOneWidget);
      expect(find.text('Airo TV'), findsNothing);
      expect(find.text('AIRO TV'), findsNothing);
      expect(find.text('Midas Stream'), findsNothing);
    },
  );

  test('tv_shell.dart user-facing literals are Aika Stream', () {
    final source = File('lib/core/app/tv_shell.dart').readAsStringSync();
    final literals = RegExp(
      r"""'(?:[^'\\]|\\.)*'|"(?:[^"\\]|\\.)*" """,
    ).allMatches(source).map((match) => match.group(0)!);
    for (final literal in literals) {
      expect(literal.contains('Airo TV'), isFalse, reason: literal);
      expect(literal.contains('AIRO TV'), isFalse, reason: literal);
      expect(literal.contains('Midas Stream'), isFalse, reason: literal);
    }
    expect(source.contains('TvStoreProduct.displayName'), isTrue);
  });
}

class _RecordingStreamingService extends VideoPlayerStreamingService {
  _RecordingStreamingService({this.stopHold})
    : super(engine: FakeAiroPlaybackEngine());

  final Completer<void>? stopHold;
  int stopCount = 0;

  @override
  Future<void> stop() async {
    stopCount++;
    final hold = stopHold;
    if (hold != null) await hold.future;
    await super.stop();
  }
}

class _FakePairingServer implements TvPlaylistPairingServer {
  _FakePairingServer({this.never = false});

  final bool never;
  final _resultCompleter = Completer<String?>();
  bool stopped = false;

  @override
  Future<Uri> start() async {
    return Uri.parse('http://192.168.1.5:8080/pair/fake-token');
  }

  @override
  Future<String?> get result {
    if (!never && !_resultCompleter.isCompleted) {
      _resultCompleter.complete(null);
    }
    return _resultCompleter.future;
  }

  @override
  Future<void> cancel() => stop();

  @override
  Future<void> stop() async {
    stopped = true;
    if (!_resultCompleter.isCompleted) _resultCompleter.complete(null);
  }

  @override
  bool get isRunning => !stopped;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
