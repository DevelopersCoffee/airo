import 'dart:async';

import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// AiroTV D-pad design's context menu (`mDefs` in the prototype) specifies
// seven actions: Favourite, Refresh playlist, Audio track, Subtitles,
// Channel info, Diagnostics, Copy stream link. Favourite/Close are covered
// in video_player_widget_context_menu_test.dart; this file covers the
// remaining five, previously entirely missing from the production overlay.
void main() {
  final channel = IPTVChannel(
    id: 'news-1',
    name: 'City News Live',
    streamUrl: 'https://example.com/secret/path/news.m3u8?token=abc123',
    group: 'News',
  );

  Future<ProviderContainer> pumpPlayer(
    WidgetTester tester, {
    List<AiroPlaybackTrackOption> tracks = const [],
    List<Override> extraOverrides = const [],
    AiroPlaybackStats? playbackStats,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        streamingStateProvider.overrideWith(
          (ref) => Stream.value(
            StreamingState(
              playbackState: PlaybackState.playing,
              isLiveStream: true,
              currentQuality: VideoQuality.high,
              currentChannel: channel,
              tracks: tracks,
              playbackStats: playbackStats,
            ),
          ),
        ),
        ...extraOverrides,
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: SizedBox(width: 960, height: 540, child: VideoPlayerWidget()),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    return container;
  }

  Future<void> openContextMenu(WidgetTester tester) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
    await tester.pump();
    expect(find.text('Actions for'), findsOneWidget);
  }

  testWidgets('context menu lists all seven prototype actions', (tester) async {
    await pumpPlayer(tester);
    await openContextMenu(tester);

    expect(find.text('Add to favorites'), findsOneWidget);
    expect(find.text('Refresh playlist'), findsOneWidget);
    expect(find.text('Audio track'), findsOneWidget);
    expect(find.text('Subtitles'), findsOneWidget);
    expect(find.text('Channel info'), findsOneWidget);
    expect(find.text('Diagnostics'), findsOneWidget);
    expect(find.text('Copy stream link'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
  });

  testWidgets(
    'Refresh playlist re-fetches channels and confirms via snackbar',
    (tester) async {
      final refreshCompleter = Completer<List<IPTVChannel>>();
      final container = await pumpPlayer(
        tester,
        extraOverrides: [
          refreshChannelsProvider.overrideWith(
            (ref, forceRefresh) => refreshCompleter.future,
          ),
        ],
      );
      await openContextMenu(tester);

      await tester.ensureVisible(find.text('Refresh playlist'));
      await tester.tap(find.text('Refresh playlist'));
      await tester.pump();
      expect(find.text('Refreshing playlist…'), findsOneWidget);

      refreshCompleter.complete([channel]);
      await tester.pump();
      await tester.pump();
      expect(find.text('Playlist refreshed'), findsOneWidget);
      // Refresh reruns the fetch that backs the main channel list too.
      expect(container.read(iptvChannelsProvider).isLoading, isTrue);
    },
  );

  testWidgets('Audio track opens the track selector scoped to audio tracks', (
    tester,
  ) async {
    await pumpPlayer(
      tester,
      tracks: const [
        AiroPlaybackTrackOption(
          id: 'a1',
          kind: AiroPlaybackTrackKind.audio,
          label: 'English',
        ),
        AiroPlaybackTrackOption(
          id: 's1',
          kind: AiroPlaybackTrackKind.subtitle,
          label: 'Français',
        ),
      ],
    );
    await openContextMenu(tester);

    await tester.tap(find.text('Audio track'));
    await tester.pump();

    expect(find.text('Actions for'), findsNothing);
    expect(find.text('English'), findsOneWidget);
    expect(find.text('Français'), findsNothing);
  });

  testWidgets('Subtitles opens the track selector scoped to subtitle tracks', (
    tester,
  ) async {
    await pumpPlayer(
      tester,
      tracks: const [
        AiroPlaybackTrackOption(
          id: 's1',
          kind: AiroPlaybackTrackKind.subtitle,
          label: 'Français',
        ),
      ],
    );
    await openContextMenu(tester);

    await tester.tap(find.text('Subtitles'));
    await tester.pump();

    expect(find.text('Actions for'), findsNothing);
    expect(find.text('Français'), findsOneWidget);
  });

  testWidgets(
    'Channel info shows real channel/quality fields and closes the menu',
    (tester) async {
      await pumpPlayer(tester);
      await openContextMenu(tester);

      await tester.tap(find.text('Channel info'));
      await tester.pump();

      expect(find.text('Actions for'), findsNothing);
      expect(find.text('Group: News'), findsOneWidget);
      expect(find.text('Quality: 720p'), findsOneWidget);
      expect(find.text('Live'), findsOneWidget);
    },
  );

  testWidgets(
    'Diagnostics shows a redacted source URI, never the raw stream URL',
    (tester) async {
      await pumpPlayer(
        tester,
        playbackStats: const AiroPlaybackStats(
          codec: 'h264',
          width: 1920,
          height: 1080,
          framesPerSecond: 25,
          droppedFrames: 31,
          audioCodec: 'aac',
          audioBitrateKbps: 128,
          audioChannels: 2,
          cacheDuration: Duration(seconds: 4),
          failoverSuggested: true,
        ),
      );
      await openContextMenu(tester);

      await tester.tap(find.text('Diagnostics'));
      await tester.pump();

      expect(find.text('Actions for'), findsNothing);
      expect(find.text('Source: https://example.com'), findsOneWidget);
      expect(find.textContaining('token=abc123'), findsNothing);
      expect(find.textContaining('/secret/path'), findsNothing);
      expect(find.text('Video codec: h264'), findsOneWidget);
      expect(find.text('Resolution: 1920x1080'), findsOneWidget);
      expect(find.text('Frame rate: 25.00 fps'), findsOneWidget);
      expect(find.text('Dropped frames: 31'), findsOneWidget);
      expect(find.text('Audio codec: aac'), findsOneWidget);
      expect(
        find.text('Playback is degraded. Try the next healthy stream source.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('Copy stream link copies the redacted URI, not the raw URL', (
    tester,
  ) async {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await pumpPlayer(tester);
    await openContextMenu(tester);

    await tester.tap(find.text('Copy stream link'));
    await tester.pump();

    expect(copied, ['https://example.com']);
    expect(find.text('Stream link copied'), findsOneWidget);
  });
}
