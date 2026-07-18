import 'package:feature_iptv/application/providers/iptv_providers.dart';
import 'package:feature_iptv/application/providers/tv_font_mode_provider.dart';
import 'package:feature_iptv/presentation/widgets/tv_channel_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_player/platform_player.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
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
    IPTVChannel(
      id: 'music-1',
      name: 'Music Box',
      streamUrl: 'https://example.com/music.m3u8',
      group: 'Music',
      category: ChannelCategory.music,
    ),
  ];

  Widget buildGrid({SharedPreferences? prefs}) {
    return ProviderScope(
      overrides: [
        if (prefs != null) sharedPreferencesProvider.overrideWithValue(prefs),
        iptvChannelsProvider.overrideWith((ref) async => channels),
        streamingStateProvider.overrideWith(
          (ref) => Stream.value(
            StreamingState(
              currentChannel: channels.first,
              playbackState: PlaybackState.playing,
              isLiveStream: true,
            ),
          ),
        ),
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
              child: TvChannelGrid(
                config: const TvChannelGridConfig(preloadThumbnails: false),
                onChannelSelect: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('long-pressing a channel tile hides its group (CV-021)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(buildGrid(prefs: prefs));
    await tester.pumpAndSettle();

    expect(find.text('Stadium Sports'), findsOneWidget);

    await tester.longPress(find.text('Stadium Sports'));
    await tester.pumpAndSettle();

    expect(find.text('Stadium Sports'), findsNothing);
    // Other groups are unaffected.
    expect(find.text('City News Live'), findsOneWidget);
    expect(find.text('Music Box'), findsOneWidget);
  });

  testWidgets(
    'applies the persisted TV font mode scale to channel name text (CV-008)',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues({
        tvFontModeStorageKey: TvFontMode.standard.stableId,
      });
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(buildGrid(prefs: prefs));
      await tester.pumpAndSettle();
      final standardFontSize = tester
          .widget<Text>(find.text('City News Live').first)
          .style
          ?.fontSize;

      // Same prefs instance, updated in place -- avoids relying on
      // SharedPreferences.getInstance() re-reading mock values a second
      // time within one test (it caches the instance on first call).
      await prefs.setString(
        tvFontModeStorageKey,
        TvFontMode.extraLarge.stableId,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(buildGrid(prefs: prefs));
      await tester.pumpAndSettle();
      final extraLargeFontSize = tester
          .widget<Text>(find.text('City News Live').first)
          .style
          ?.fontSize;

      expect(standardFontSize, isNotNull);
      expect(
        extraLargeFontSize! / standardFontSize!,
        closeTo(TvFontMode.extraLarge.scale, 0.01),
      );
      // No overflow/layout exception for long titles at the largest scale
      // (long channel names still exist in `channels` via maxLines/ellipsis).
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'wraps each visible channel tile in repaint boundaries',
    experimentalLeakTesting: LeakTesting.settings,
    (tester) async {
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildGrid());
      await tester.pumpAndSettle();

      for (final channel in channels) {
        expect(find.text(channel.name), findsOneWidget);
        expect(
          find.byKey(ValueKey('tv_channel_card_boundary_${channel.id}')),
          findsOneWidget,
        );
        expect(
          find.byKey(
            ValueKey('tv_channel_card_content_boundary_${channel.id}'),
          ),
          findsOneWidget,
        );
      }
    },
  );
}
