import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// AiroTV D-pad design's "RECENT CHANNELS (DOWN)" screen.
void main() {
  Future<ProviderContainer> pumpPlayer(
    WidgetTester tester, {
    required List<IPTVChannel> recent,
    VoidCallback? onFullscreenToggle,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        recentlyWatchedChannelsProvider.overrideWith((ref) async => recent),
        streamingStateProvider.overrideWith(
          (ref) => Stream.value(
            StreamingState(
              playbackState: PlaybackState.playing,
              isLiveStream: true,
              currentChannel: IPTVChannel(
                id: 'news-1',
                name: 'City News Live',
                streamUrl: 'https://example.com/news.m3u8',
                group: 'News',
              ),
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 960,
              height: 540,
              child: VideoPlayerWidget(
                initiallyFullscreen: onFullscreenToggle != null,
                onFullscreenToggle: onFullscreenToggle,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    return container;
  }

  testWidgets('DOWN opens Recent Channels, and BACK closes it again', (
    tester,
  ) async {
    var fullscreenCloseCount = 0;
    await pumpPlayer(
      tester,
      onFullscreenToggle: () => fullscreenCloseCount++,
      recent: const [
        IPTVChannel(
          id: 'sports-1',
          name: 'Stadium Sports',
          streamUrl: 'https://example.com/sports.m3u8',
          group: 'Sports',
        ),
      ],
    );

    expect(find.text('Recently watched'), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.pump();

    expect(find.text('Recently watched'), findsOneWidget);
    expect(find.text('Stadium Sports'), findsOneWidget);

    // Fire OS delivers a raw BACK key before the paired platform pop-route
    // request. The raw event closes the overlay and suppresses the platform
    // half of the same button press.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.text('Recently watched'), findsNothing);

    // A physical Fire TV Stick delayed this platform callback while the video
    // surface was active.
    await tester.pump(const Duration(seconds: 3));
    final handled = await tester.binding.handlePopRoute();
    await tester.pump();

    expect(handled, isTrue);
    expect(find.text('Recently watched'), findsNothing);
    expect(fullscreenCloseCount, 0);

    // Fire OS can issue another pop-route callback for the same physical
    // BACK. It must remain paired with the overlay dismissal rather than
    // being reinterpreted as a request to exit fullscreen.
    final duplicateHandled = await tester.binding.handlePopRoute();
    await tester.pump();
    expect(duplicateHandled, isTrue);
    expect(fullscreenCloseCount, 0);
  });

  // The suppression latch set by the Recent Channels dismissal above stays
  // armed until the next raw BACK. It must only ever hold back the fullscreen
  // exit -- an overlay opened while it is armed still has to close on BACK, or
  // the user is stranded in a menu with no way out.
  testWidgets('BACK still closes a context menu opened after Recent Channels '
      'was dismissed', (tester) async {
    var fullscreenCloseCount = 0;
    await pumpPlayer(
      tester,
      onFullscreenToggle: () => fullscreenCloseCount++,
      recent: const [
        IPTVChannel(
          id: 'sports-1',
          name: 'Stadium Sports',
          streamUrl: 'https://example.com/sports.m3u8',
          group: 'Sports',
        ),
      ],
    );

    // Arm the latch: DOWN opens Recent Channels, BACK dismisses it.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.pump();
    expect(find.text('Recently watched'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.text('Recently watched'), findsNothing);

    // Long-press SELECT opens the context menu while the latch is still armed.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
    await tester.pump();
    expect(find.text('Actions for'), findsOneWidget);

    // The platform back request must dismiss the menu, not be swallowed by the
    // stale latch and not exit fullscreen.
    final handled = await tester.binding.handlePopRoute();
    await tester.pump();

    expect(handled, isTrue);
    expect(find.text('Actions for'), findsNothing);
    expect(fullscreenCloseCount, 0);
  });

  testWidgets('DOWN with no recent channels renders nothing', (tester) async {
    await pumpPlayer(tester, recent: const []);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.pump();

    expect(find.text('Recently watched'), findsNothing);
  });
}
