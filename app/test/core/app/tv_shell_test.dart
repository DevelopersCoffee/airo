import 'package:airo_app/core/app/tv_router.dart';
import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'TV sidebar has no separate Home tab and Live TV is first',
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
        initialLocation: TvRouteNames.live,
      );

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
                const StreamingState(
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

      expect(find.byType(NavigationRail), findsOneWidget);
      final rail = tester.widget<NavigationRail>(
        find.byType(NavigationRail),
      );
      expect(rail.destinations, hasLength(5));

      final railLabels = rail.destinations
          .map((d) => (d.label as Text).data)
          .toList();
      expect(railLabels, [
        'Live TV',
        'Guide',
        'Movies & Shows',
        'Favorites',
        'Settings',
      ]);
    },
  );
}
