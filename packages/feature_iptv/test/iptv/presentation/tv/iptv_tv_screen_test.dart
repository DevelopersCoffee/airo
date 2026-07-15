import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:feature_iptv/presentation/utils/native_fullscreen.dart';

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
      name: 'Music India',
      streamUrl: 'https://example.com/music.m3u8',
      group: 'Music',
      category: ChannelCategory.music,
    ),
    const IPTVChannel(
      id: 'news-2',
      name: 'Global News',
      streamUrl: 'https://example.com/global-news.m3u8',
      group: 'News',
      category: ChannelCategory.news,
    ),
    const IPTVChannel(
      id: 'sports-2',
      name: 'Match Center',
      streamUrl: 'https://example.com/match-center.m3u8',
      group: 'Sports',
      category: ChannelCategory.sports,
    ),
  ];

  Future<void> pumpScreen(
    WidgetTester tester, {
    List<IPTVChannel>? visibleChannels,
    StreamingState streamingState = const StreamingState(
      playbackState: PlaybackState.idle,
      isLiveStream: true,
    ),
    Size surfaceSize = const Size(1280, 720),
    bool settle = true,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = surfaceSize;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          iptvChannelsProvider.overrideWith(
            (ref) async => visibleChannels ?? channels,
          ),
          recentlyWatchedChannelsProvider.overrideWith((ref) async => const []),
          streamingStateProvider.overrideWith(
            (ref) => Stream.value(streamingState),
          ),
        ],
        child: const MaterialApp(home: IptvTvScreen()),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('renders TV browsing surface with categories and actions', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.text('Live channels'), findsOneWidget);
    expect(find.text('Airo TV Lite Receiver'), findsOneWidget);
    expect(find.text('Compatible profile'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Live'), findsOneWidget);
    expect(find.text('Favorites'), findsOneWidget);
    expect(find.text('Recent'), findsWidgets);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Diagnostics'), findsOneWidget);
    expect(find.text('Guide'), findsNothing);
    expect(find.textContaining('Profile-limited:'), findsOneWidget);
    expect(find.text('5 of 5 live channels'), findsOneWidget);
    expect(find.text('Browse'), findsOneWidget);
    expect(find.text('All'), findsWidgets);
    expect(find.text('News'), findsWidgets);
    expect(find.text('Sports'), findsWidgets);
    expect(find.text('Music'), findsWidgets);
    expect(find.text('Business'), findsNothing);
    expect(find.text('General'), findsNothing);
    expect(find.text('Search'), findsWidgets);
    expect(find.text('Playlist'), findsOneWidget);
    expect(find.text('Help'), findsOneWidget);
    expect(find.text('Refresh'), findsOneWidget);
    expect(find.text('City News Live'), findsOneWidget);
    expect(find.text('Music India'), findsOneWidget);
    expect(find.byType(Scrollbar), findsOneWidget);
    expect(find.bySemanticsLabel('Search'), findsWidgets);
    expect(find.bySemanticsLabel('City News Live'), findsOneWidget);
  });

  testWidgets('keeps compact TV viewport browse controls reachable', (
    tester,
  ) async {
    await pumpScreen(tester, surfaceSize: const Size(1024, 576));

    expect(find.text('Live channels'), findsOneWidget);
    expect(find.text('Search'), findsWidgets);
    expect(find.text('Playlist'), findsOneWidget);
    expect(find.text('Help'), findsOneWidget);
    expect(find.text('Refresh'), findsOneWidget);
    expect(find.text('Browse'), findsOneWidget);
    expect(find.text('City News Live'), findsOneWidget);
    expect(find.byType(Scrollbar), findsOneWidget);
  });

  testWidgets('shows macOS update action on desktop builds', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      await pumpScreen(tester, surfaceSize: const Size(1440, 900));

      expect(find.text('Update'), findsOneWidget);
      expect(find.bySemanticsLabel('Update'), findsWidgets);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('shows readable playlist guide with primary dismissal', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(find.text('How to add a playlist'), findsOneWidget);
    expect(find.text('Find your playlist URL'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Done'), findsOneWidget);
  });

  testWidgets('opens fullscreen player from embedded TV controls', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      streamingState: StreamingState(
        currentChannel: channels[2],
        playbackState: PlaybackState.playing,
        isLiveStream: true,
      ),
      surfaceSize: const Size(1440, 900),
      settle: false,
    );

    expect(find.text('Music India'), findsWidgets);
    expect(
      find.byKey(const ValueKey('airo-tv-fullscreen-player')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const ValueKey('iptv-player-fullscreen-button')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(
      find.byKey(const ValueKey('airo-tv-fullscreen-player')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('airo-tv-fullscreen-video-player')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('airo-tv-fullscreen-player')),
        matching: find.byIcon(Icons.fullscreen_exit),
      ),
      findsOneWidget,
    );

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('airo-tv-fullscreen-player')),
        matching: find.byKey(const ValueKey('iptv-player-fullscreen-button')),
      ),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('native fullscreen exit restores TV screen without blanking', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      streamingState: StreamingState(
        currentChannel: channels[2],
        playbackState: PlaybackState.playing,
        isLiveStream: true,
      ),
      surfaceSize: const Size(1440, 900),
      settle: false,
    );

    await tester.tap(
      find.byKey(const ValueKey('iptv-player-fullscreen-button')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(
      find.byKey(const ValueKey('airo-tv-fullscreen-player')),
      findsOneWidget,
    );
    expect(AiroNativeFullscreen.debugHasMacosFullscreenExitHandler, isTrue);

    AiroNativeFullscreen.debugNotifyMacosFullscreenExited();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(
      find.byKey(const ValueKey('airo-tv-fullscreen-player')),
      findsNothing,
    );
    expect(find.text('Live channels'), findsOneWidget);
    expect(find.text('Browse'), findsOneWidget);
    expect(find.text('Music India'), findsWidgets);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('shows TV empty playlist state', (tester) async {
    await pumpScreen(tester, visibleChannels: const []);

    expect(find.text('Airo TV Lite Receiver'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Guide'), findsNothing);
    expect(find.text('Add your playlist'), findsOneWidget);
    expect(find.text('Import playlist URL'), findsOneWidget);
    expect(find.text('How to add'), findsOneWidget);
  });
}
