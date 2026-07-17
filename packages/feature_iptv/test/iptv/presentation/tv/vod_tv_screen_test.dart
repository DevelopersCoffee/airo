import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:feature_iptv/application/providers/iptv_providers.dart';
import 'package:feature_iptv/presentation/tv/vod_tv_screen.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  const movie = IPTVChannel(
    id: 'm3u-1',
    name: 'Example Movie',
    streamUrl: 'https://example.com/movie.mp4',
    group: 'Movies',
    category: ChannelCategory.movies,
  );

  testWidgets('shows VOD grid content when the source has VOD entries', (tester) async {
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          iptvChannelsProvider.overrideWith((ref) async => [movie]),
        ],
        child: const MaterialApp(home: VodTvScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Example Movie'), findsOneWidget);
  });

  testWidgets('shows empty state when the source has no VOD entries', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    const liveOnly = IPTVChannel(
      id: 'm3u-2',
      name: 'Example News',
      streamUrl: 'https://example.com/news.m3u8',
      group: 'News',
      category: ChannelCategory.news,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          iptvChannelsProvider.overrideWith((ref) async => [liveOnly]),
        ],
        child: const MaterialApp(home: VodTvScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('No movies or shows found'), findsOneWidget);
  });

  testWidgets(
    'mounting fresh when iptvChannelsProvider is already resolved does not '
    'throw setState-during-build (regression for cold VodGrid provider chain)',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          iptvChannelsProvider.overrideWith((ref) async => [movie]),
        ],
      );
      addTearDown(container.dispose);

      // Simulate the channel list already having been fetched by an
      // earlier-visited screen (e.g. the live-channels tab) before the VOD
      // screen — and its VodGrid — ever mounts.
      await container.read(iptvChannelsProvider.future);

      final errors = <FlutterErrorDetails>[];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = errors.add;
      addTearDown(() => FlutterError.onError = originalOnError);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: VodTvScreen()),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(
        errors,
        isEmpty,
        reason: 'VodGrid mount triggered a Flutter error: ${errors.map((e) => e.exception).join(', ')}',
      );
      expect(find.text('Example Movie'), findsOneWidget);
    },
  );
}
