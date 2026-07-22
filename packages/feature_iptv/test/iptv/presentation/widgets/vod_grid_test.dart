import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:feature_iptv/application/providers/iptv_providers.dart';
import 'package:feature_iptv/presentation/widgets/vod_grid.dart';
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

  testWidgets('renders a card per standalone VOD movie', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          iptvChannelsProvider.overrideWith((ref) async => [movie]),
        ],
        child: MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(1280, 720),
              navigationMode: NavigationMode.directional,
            ),
            child: Scaffold(
              body: SizedBox(
                width: 1280,
                height: 720,
                child: VodGrid(onItemSelect: (_) {}),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Example Movie'), findsOneWidget);
  });

  testWidgets('shows empty state when there are no VOD entries', (
    tester,
  ) async {
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
        child: const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(1280, 720),
              navigationMode: NavigationMode.directional,
            ),
            child: Scaffold(
              body: SizedBox(width: 1280, height: 720, child: VodGrid()),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('No movies or shows found'), findsOneWidget);
  });
}
