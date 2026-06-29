import 'package:airo_app/features/iptv/application/providers/iptv_providers.dart';
import 'package:airo_app/features/iptv/domain/models/iptv_channel.dart';
import 'package:airo_app/features/iptv/domain/models/streaming_state.dart';
import 'package:airo_app/features/iptv/presentation/screens/iptv_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final channels = [
    const IPTVChannel(
      id: 'news-1',
      name: 'City News Live',
      streamUrl: 'https://example.com/news.m3u8',
      group: 'News',
      category: ChannelCategory.news,
    ),
    const IPTVChannel(
      id: 'sports-1',
      name: 'Stadium Sports',
      streamUrl: 'https://example.com/sports.m3u8',
      group: 'Sports',
      category: ChannelCategory.sports,
    ),
    const IPTVChannel(
      id: 'music-1',
      name: 'Music Box',
      streamUrl: 'https://example.com/music.m3u8',
      group: 'Music',
      category: ChannelCategory.music,
    ),
  ];

  Widget createWidget() {
    SharedPreferences.setMockInitialValues({});
    return FutureBuilder<SharedPreferences>(
      future: SharedPreferences.getInstance(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const MaterialApp(
            home: Scaffold(body: CircularProgressIndicator()),
          );
        }

        return ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(snapshot.data!),
            iptvChannelsProvider.overrideWith((ref) async => channels),
            recentlyWatchedChannelsProvider.overrideWith(
              (ref) async => const [],
            ),
            streamingStateProvider.overrideWith(
              (ref) => Stream.value(
                const StreamingState(
                  playbackState: PlaybackState.idle,
                  isLiveStream: true,
                  liveDelay: Duration(seconds: 1),
                ),
              ),
            ),
          ],
          child: const MaterialApp(home: IPTVScreen()),
        );
      },
    );
  }

  testWidgets('renders Stream app bar, category filters, and live list', (
    tester,
  ) async {
    await tester.pumpWidget(createWidget());
    await tester.pumpAndSettle();

    expect(find.text('Stream'), findsOneWidget);
    expect(find.byTooltip('Search channels'), findsOneWidget);
    expect(find.byTooltip('Cast'), findsOneWidget);
    expect(find.text('All (3)'), findsOneWidget);
    expect(find.text('News (1)'), findsOneWidget);
    expect(find.text('Sports (1)'), findsOneWidget);
    expect(find.text('Entertainment (0)'), findsOneWidget);
    expect(find.text('Music (1)'), findsOneWidget);
    expect(find.text('Featured Player'), findsOneWidget);
    expect(find.text('Select a channel to start watching'), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -320));
    await tester.pumpAndSettle();

    expect(find.text('Live Channels'), findsOneWidget);
    expect(find.text('City News Live'), findsOneWidget);
    expect(find.text('LIVE'), findsWidgets);
  });

  testWidgets('opens search sheet from app bar action', (tester) async {
    await tester.pumpWidget(createWidget());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Search channels'));
    await tester.pumpAndSettle();

    expect(find.text('Search channels'), findsOneWidget);
    expect(find.text('Find live channels by name or group.'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
  });
}
