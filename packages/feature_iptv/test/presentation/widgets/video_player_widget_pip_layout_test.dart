import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// #1002: while system PiP is active the player renders the video surface
// only — no controls overlay, lock button, or other chrome that would
// clutter the floating window.
void main() {
  Future<void> pumpPlayer(WidgetTester tester, {required bool pipActive}) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          pictureInPictureActiveProvider.overrideWith((ref) => pipActive),
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
                  category: ChannelCategory.news,
                ),
              ),
            ),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: VideoPlayerWidget())),
      ),
    );
    // Bounded pumps only: the real streaming service's state stream and the
    // overlay auto-hide timer keep frames scheduled indefinitely, so
    // pumpAndSettle never converges (same pattern as the sibling
    // background-modes widget test).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('PiP active hides all player chrome', (tester) async {
    await pumpPlayer(tester, pipActive: true);

    expect(find.byKey(const ValueKey('iptv-player-lock-button')), findsNothing);
    expect(find.byKey(const ValueKey('audio-only-toggle')), findsNothing);
  });

  testWidgets('PiP inactive shows normal player chrome', (tester) async {
    await pumpPlayer(tester, pipActive: false);

    expect(
      find.byKey(const ValueKey('iptv-player-lock-button')),
      findsOneWidget,
    );
  });
}
