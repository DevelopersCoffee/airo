import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('tapping the audio-only toggle enables background audio mode', (
    tester,
  ) async {
    const channel = MethodChannel('com.airo.player/background_audio_mode');
    AiroBackgroundAudioMode.debugSetMethodChannel(channel);
    AiroBackgroundAudioMode.debugReset();
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          streamingStateProvider.overrideWith(
            (ref) => Stream.value(
              StreamingState(
                playbackState: PlaybackState.idle,
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
    // Avoid pumpAndSettle: the real (unmocked) streaming service's state
    // stream and the overlay's auto-hide timer keep frames scheduled
    // indefinitely, so pumpAndSettle never converges. A couple of bounded
    // pumps is enough to let the initial frame and provider wiring settle,
    // matching the pattern used by the sibling widget test in
    // test/iptv/presentation/widgets/video_player_widget_test.dart.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byKey(const ValueKey('audio-only-toggle')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(calls.single.arguments, {'enabled': true});
    expect(AiroBackgroundAudioMode.isEnabled, isTrue);
  });
}
