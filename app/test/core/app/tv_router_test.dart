import 'package:airo_app/core/app/tv_router.dart';
import 'package:airo_app/core/platform/device_form_factor.dart';
import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<void> pumpTvRouter(
    WidgetTester tester, {
    required String initialLocation,
    Size? surfaceSize,
  }) async {
    if (surfaceSize != null) {
      await tester.binding.setSurfaceSize(surfaceSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));
    }

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final router = TvRouter.createRouter(initialLocation: initialLocation);

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
  }

  testWidgets('starts on live TV without requiring login', (tester) async {
    await pumpTvRouter(
      tester,
      initialLocation: TvRouteNames.live,
      surfaceSize: const Size(1280, 720),
    );

    expect(find.text('Add your playlist'), findsOneWidget);
    expect(find.text('Welcome to Airo'), findsNothing);
  });

  testWidgets('uses compact IPTV layout on phone portrait viewports', (
    tester,
  ) async {
    await pumpTvRouter(
      tester,
      initialLocation: TvRouteNames.live,
      surfaceSize: const Size(390, 844),
    );

    expect(find.text('Add your playlist'), findsOneWidget);
    expect(find.text('Live TV'), findsNothing);
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Appearance'), findsOneWidget);
    expect(find.widgetWithText(AppBar, 'Settings'), findsOneWidget);
  });

  testWidgets('uses compact IPTV layout on short phone landscape viewports', (
    tester,
  ) async {
    await pumpTvRouter(
      tester,
      initialLocation: TvRouteNames.live,
      surfaceSize: const Size(1090, 485),
    );

    expect(find.text('Add your playlist'), findsOneWidget);
    expect(find.text('Live TV'), findsNothing);
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets(
    'detected TV keeps the 10-foot layout even at phone-sized logical '
    'viewports (Fire TV Stick reports 960x540 logical at density 2.0)',
    (tester) async {
      DeviceFormFactorDetector.debugFormFactorOverride = DeviceFormFactor.tv;
      addTearDown(DeviceFormFactorDetector.clearCache);

      await pumpTvRouter(
        tester,
        initialLocation: TvRouteNames.live,
        surfaceSize: const Size(960, 540),
      );

      // Phone chrome must not leak onto a real TV: no hamburger drawer and
      // no Cast entry point (the TV is the receiver, not a sender).
      expect(find.byIcon(Icons.menu), findsNothing);
      expect(find.byIcon(Icons.cast_connected), findsNothing);
    },
  );

  testWidgets(
    'phone-sized viewport without TV detection still gets compact layout',
    (tester) async {
      DeviceFormFactorDetector.clearCache();
      addTearDown(DeviceFormFactorDetector.clearCache);

      await pumpTvRouter(
        tester,
        initialLocation: TvRouteNames.live,
        surfaceSize: const Size(390, 844),
      );

      expect(find.byIcon(Icons.menu), findsOneWidget);
    },
  );

  testWidgets(
    'TV renders the 10-foot AiroTvShell with no phone chrome, and keeps '
    'playlist source reachable without an app bar',
    (tester) async {
      DeviceFormFactorDetector.debugFormFactorOverride = DeviceFormFactor.tv;
      addTearDown(DeviceFormFactorDetector.clearCache);

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.binding.setSurfaceSize(const Size(960, 540));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            iptvChannelsProvider.overrideWith(
              (ref) async => const [
                IPTVChannel(
                  id: 'ch1',
                  name: 'Test Channel',
                  streamUrl: 'https://example.com/ch1.m3u8',
                ),
              ],
            ),
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
          child: MaterialApp.router(
            routerConfig: TvRouter.createRouter(
              initialLocation: TvRouteNames.live,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The 10-foot shell, not the older IptvTvScreen.
      expect(
        find.byKey(const ValueKey('airo-tv-explorer-wide-shell')),
        findsOneWidget,
      );
      // No phone chrome on a television.
      expect(find.byIcon(Icons.menu), findsNothing);
      expect(find.byIcon(Icons.cast_connected), findsNothing);
      // Removing the app bar must not strand playlist source — Settings has
      // no playlist entry, so it lives in the LIVE bar on TV.
      expect(find.bySemanticsLabel('Playlist source'), findsOneWidget);
    },
  );

  testWidgets(
    'sidebar navigation overlays Guide without unmounting the live shell '
    '(playback must never stop for a menu tap)',
    (tester) async {
      DeviceFormFactorDetector.debugFormFactorOverride = DeviceFormFactor.tv;
      addTearDown(DeviceFormFactorDetector.clearCache);

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.binding.setSurfaceSize(const Size(960, 540));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            iptvChannelsProvider.overrideWith(
              (ref) async => const [
                IPTVChannel(
                  id: 'ch1',
                  name: 'Test Channel',
                  streamUrl: 'https://example.com/ch1.m3u8',
                ),
              ],
            ),
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
          child: MaterialApp.router(
            routerConfig: TvRouter.createRouter(
              initialLocation: TvRouteNames.live,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('airo-tv-explorer-wide-shell')),
        findsOneWidget,
      );

      await tester.tap(find.text('Guide'));
      await tester.pumpAndSettle();

      // The live shell (and the video widget it hosts) is still in the
      // tree underneath the Guide overlay — a sidebar tap must not tear
      // it down and rebuild it from scratch.
      expect(
        find.byKey(const ValueKey('airo-tv-explorer-wide-shell')),
        findsOneWidget,
      );
      expect(find.text('Guide'), findsWidgets);

      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('airo-tv-explorer-wide-shell')),
        findsOneWidget,
      );
    },
  );

  testWidgets('redirects legacy login route to live TV', (tester) async {
    await pumpTvRouter(
      tester,
      initialLocation: TvRouteNames.legacyLogin,
      surfaceSize: const Size(1280, 720),
    );

    expect(find.text('Add your playlist'), findsOneWidget);
    expect(find.text('Welcome to Airo'), findsNothing);
  });

  testWidgets('favorites route renders the real favorites screen', (
    tester,
  ) async {
    await pumpTvRouter(
      tester,
      initialLocation: TvRouteNames.favorites,
      surfaceSize: const Size(1280, 720),
    );

    expect(find.text('Favorites'), findsOneWidget);
    expect(find.text('Coming soon'), findsNothing);
    expect(find.text('No favorite channels yet'), findsOneWidget);
  });

  testWidgets('compact settings route shows a back button to live TV', (
    tester,
  ) async {
    await pumpTvRouter(
      tester,
      initialLocation: TvRouteNames.settings,
      surfaceSize: const Size(390, 844),
    );

    expect(find.widgetWithText(AppBar, 'Settings'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.text('Add your playlist'), findsOneWidget);
    expect(find.widgetWithText(AppBar, 'Settings'), findsNothing);
  });

  testWidgets('compact settings route handles Android back by returning live', (
    tester,
  ) async {
    await pumpTvRouter(
      tester,
      initialLocation: TvRouteNames.settings,
      surfaceSize: const Size(390, 844),
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Add your playlist'), findsOneWidget);
    expect(find.widgetWithText(AppBar, 'Settings'), findsNothing);
  });
}
