import 'package:feature_iptv/feature_iptv.dart';
import 'package:feature_iptv/presentation/widgets/player_brightness_controller.dart';
import 'package:feature_iptv/presentation/widgets/player_lock_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<void> pumpPlayer(
    WidgetTester tester, {
    bool enableSwipeChannelChange = false,
    PlayerBrightnessController? brightnessController,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          streamingStateProvider.overrideWith(
            (ref) => Stream.value(
              const StreamingState(
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
        child: MaterialApp(
          home: VideoPlayerWidget(
            enableSwipeChannelChange: enableSwipeChannelChange,
            brightnessController: brightnessController,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets(
    'locking hides playback controls but keeps the lock button interactive',
    (tester) async {
      await pumpPlayer(tester, enableSwipeChannelChange: true);

      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      expect(find.byIcon(Icons.skip_previous), findsOneWidget);
      expect(find.byIcon(Icons.skip_next), findsOneWidget);

      await tester.tap(find.byType(PlayerLockButton));
      await tester.pump();

      expect(find.byIcon(Icons.play_arrow), findsNothing);
      expect(find.byIcon(Icons.skip_previous), findsNothing);
      expect(find.byIcon(Icons.skip_next), findsNothing);
      expect(find.byType(PlayerLockButton), findsOneWidget);
    },
  );

  testWidgets('tapping the lock button again unlocks and restores controls', (
    tester,
  ) async {
    await pumpPlayer(tester);

    await tester.tap(find.byType(PlayerLockButton));
    await tester.pump();
    expect(find.byIcon(Icons.play_arrow), findsNothing);

    await tester.tap(find.byType(PlayerLockButton));
    await tester.pump();
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
  });

  testWidgets('resets brightness via the injected controller on dispose', (
    tester,
  ) async {
    final controller = FakePlayerBrightnessController(initial: 0.6);
    await pumpPlayer(tester, brightnessController: controller);
    expect(controller.resetCalls, 0);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(controller.resetCalls, 1);
  });
}
