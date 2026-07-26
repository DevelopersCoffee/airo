import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The playback error/diagnostic message and the transport controls overlay
// (play/pause, scrub bar) render in the same Stack, and the controls are
// only opacity-toggled, never removed. A vertically-centered error message
// can grow tall enough to sit under the bottom control bar. The fix anchors
// the error to the upper band so the two can never collide.
void main() {
  const viewportHeight = 540.0;

  Future<void> pumpErrorPlayer(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    const mapper = AiroPlaybackDiagnosticMapper();
    final diagnostic = mapper.map(
      const AiroPlaybackFailureEvent(httpStatusCode: 403),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          streamingStateProvider.overrideWith(
            (ref) => Stream.value(
              StreamingState(
                playbackState: PlaybackState.error,
                isLiveStream: true,
                diagnostic: diagnostic,
                retryCount: 0,
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
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 960,
              height: viewportHeight,
              child: const VideoPlayerWidget(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets(
    'diagnostic error message stays in the upper band, clear of the '
    'bottom transport controls',
    (tester) async {
      await pumpErrorPlayer(tester);

      expect(find.text('Your provider rejected this stream. Check your playlist credentials.'), findsOneWidget);

      final messageTop = tester
          .getTopLeft(
            find.text(
              'Your provider rejected this stream. Check your playlist credentials.',
            ),
          )
          .dy;

      // Upper-band placement: the message must start well above vertical
      // center, leaving the whole bottom half clear for transport controls.
      expect(messageTop, lessThan(viewportHeight * 0.3));
    },
  );
}
