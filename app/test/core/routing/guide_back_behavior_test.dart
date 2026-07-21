import 'package:airo_app/core/routing/app_router.dart';
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
    String initialLocation = '/guide',
  }) async {
    SharedPreferences.setMockInitialValues({'is_logged_in': true});
    final prefs = await SharedPreferences.getInstance();
    final router = AppRouter.createRouter(initialLocation: initialLocation);

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

  testWidgets('guide tab renders the guide screen', (tester) async {
    final router = await pumpApp(tester);

    expect(_currentPath(router), '/guide');
    expect(find.text('Search the guide'), findsOneWidget);
  });

  testWidgets('system back on the guide root tab keeps the shell sane', (
    tester,
  ) async {
    final router = await pumpApp(tester);

    expect(_currentPath(router), '/guide');
    expect(find.text('Search the guide'), findsOneWidget);

    final didPop = await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(didPop, isFalse);
    expect(_currentPath(router), '/guide');
    expect(find.text('Search the guide'), findsOneWidget);
    expect(find.byType(Scaffold), findsAtLeastNWidgets(1));
  });

  testWidgets('back from a route pushed on top of guide returns to guide', (
    tester,
  ) async {
    final router = await pumpApp(tester);
    router.go('/guide');
    await tester.pump();
    await tester.pump();

    expect(_currentPath(router), '/guide');
    expect(router.canPop(), isFalse);

    router.push('/mind/notifications');
    await tester.pumpAndSettle();

    expect(router.canPop(), isTrue);
    expect(find.text('Notifications (0)'), findsOneWidget);

    final didPop = await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(didPop, isTrue);
    expect(_currentPath(router), '/guide');
    expect(router.canPop(), isFalse);
    expect(find.text('Notifications (0)'), findsNothing);
    expect(find.text('Search the guide'), findsOneWidget);
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
