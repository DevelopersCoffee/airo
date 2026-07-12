import 'package:airo_app/core/app/tv_router.dart';
import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<void> pumpTvRouter(
    WidgetTester tester, {
    required String initialLocation,
  }) async {
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
  }

  testWidgets('starts on live TV without requiring login', (tester) async {
    await pumpTvRouter(tester, initialLocation: TvRouteNames.live);

    expect(find.text('Stream'), findsOneWidget);
    expect(find.text('Welcome to Airo'), findsNothing);
  });

  testWidgets('redirects legacy login route to live TV', (tester) async {
    await pumpTvRouter(tester, initialLocation: TvRouteNames.legacyLogin);

    expect(find.text('Stream'), findsOneWidget);
    expect(find.text('Welcome to Airo'), findsNothing);
  });
}
