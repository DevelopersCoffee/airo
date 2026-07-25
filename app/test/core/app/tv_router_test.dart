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
