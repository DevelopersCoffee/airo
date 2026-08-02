import 'package:airo_app/core/routing/app_router.dart';
import 'package:airo_app/main.dart';
import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final fixedNow = DateTime.utc(2026, 7, 21, 12);

  const channels = [
    IPTVChannel(
      id: 'news-1',
      name: 'City News Live',
      streamUrl: 'https://example.com/news.m3u8',
      group: 'News',
      category: ChannelCategory.news,
    ),
    IPTVChannel(
      id: 'sports-1',
      name: 'Stadium Sports',
      streamUrl: 'https://example.com/sports.m3u8',
      group: 'Sports',
      category: ChannelCategory.sports,
    ),
  ];

  Future<GoRouter> pumpApp(
    WidgetTester tester, {
    String initialLocation = '/iptv',
  }) async {
    SharedPreferences.setMockInitialValues({'is_logged_in': true});
    final prefs = await SharedPreferences.getInstance();
    final router = AppRouter.createRouter(
      moduleRegistry: buildMainModuleRegistry(),
      initialLocation: initialLocation,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          iptvChannelsProvider.overrideWith((ref) async => channels),
          streamingStateProvider.overrideWith(
            (ref) => Stream.value(
              StreamingState(
                playbackState: PlaybackState.idle,
                isLiveStream: true,
              ),
            ),
          ),
          recentlyWatchedChannelsProvider.overrideWith((ref) async => const []),
          favoriteChannelIdsProvider.overrideWith((ref) async => const {}),
          hiddenGroupIdsProvider.overrideWith((ref) async => const {}),
          guidePagedWindowProvider.overrideWith(
            () => _FakePagedNotifier(
              GuidePagedWindowState(
                earliestStart: fixedNow.subtract(const Duration(minutes: 30)),
                loadedThrough: fixedNow.add(const Duration(hours: 3)),
                window: CompactEpgWindow(
                  entries: const [],
                  windowStart: fixedNow.subtract(const Duration(minutes: 30)),
                  windowEnd: fixedNow.add(const Duration(hours: 3)),
                  generatedAt: fixedNow,
                  expiresAt: fixedNow.add(const Duration(hours: 1)),
                  source: CompactEpgSliceSource.unavailable,
                ),
              ),
            ),
          ),
          nowTickerProvider.overrideWith((ref) => Stream.value(fixedNow)),
          epgRemindersProvider.overrideWith((ref) async => const []),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump();

    return router;
  }

  // Guide is no longer a top-level GoRouter tab: it lives only inside the
  // IPTV section's own drawer (IptvNavigationDrawer -> IPTVScreen._openGuide),
  // pushed with a plain Navigator.push on the IPTV screen's own Navigator.
  // The GoRouter location therefore stays at '/iptv' throughout.
  Future<void> openGuideFromIptvDrawer(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.menu).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guide'));
    await tester.pumpAndSettle();
  }

  testWidgets('opening Guide from the IPTV drawer renders the guide screen', (
    tester,
  ) async {
    final router = await pumpApp(tester);

    await openGuideFromIptvDrawer(tester);

    expect(_currentPath(router), '/iptv');
    expect(find.text('Search the guide'), findsOneWidget);
  });

  testWidgets('system back on a pushed guide screen returns to IPTV', (
    tester,
  ) async {
    final router = await pumpApp(tester);

    await openGuideFromIptvDrawer(tester);
    expect(find.text('Search the guide'), findsOneWidget);

    final didPop = await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(didPop, isTrue);
    expect(_currentPath(router), '/iptv');
    expect(find.text('Search the guide'), findsNothing);
    expect(find.byType(Scaffold), findsAtLeastNWidgets(1));
  });
}

String _currentPath(GoRouter router) {
  return router.routerDelegate.currentConfiguration.uri.path;
}

class _FakePagedNotifier extends GuidePagedWindowNotifier {
  _FakePagedNotifier(this._state);

  final GuidePagedWindowState _state;

  @override
  GuidePagedWindowState build() => _state;
}
