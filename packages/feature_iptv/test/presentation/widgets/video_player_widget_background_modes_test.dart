import 'package:feature_iptv/feature_iptv.dart';
import 'package:feature_iptv/application/player_backgrounding_coordinator.dart';
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

  testWidgets(
    'a genuinely successful toggle sequence still notifies the coordinator '
    'for both enable and disable',
    (tester) async {
      const channel = MethodChannel('com.airo.player/background_audio_mode');
      AiroBackgroundAudioMode.debugSetMethodChannel(channel);
      AiroBackgroundAudioMode.debugReset();

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => null);
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      var successfulToggles = 0;

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
            playerBackgroundingCoordinatorProvider.overrideWithValue(
              SpyPlayerBackgroundingCoordinator(
                onManualAudioOnlyToggled: () {
                  successfulToggles++;
                },
              ),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: VideoPlayerWidget())),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const ValueKey('audio-only-toggle')), findsWidgets);

      // First toggle succeeds
      await tester.tap(find.byKey(const ValueKey('audio-only-toggle')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        successfulToggles,
        equals(1),
        reason: 'First toggle should succeed',
      );
      expect(AiroBackgroundAudioMode.isEnabled, isTrue);

      // Now toggle back off, which should also succeed
      await tester.tap(find.byKey(const ValueKey('audio-only-toggle')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        successfulToggles,
        equals(2),
        reason: 'Second toggle should succeed',
      );
      expect(AiroBackgroundAudioMode.isEnabled, isFalse);
    },
  );

  testWidgets(
    'when the platform call throws, the toggle button state reverts and '
    'manualAudioOnlyToggled is not called',
    (tester) async {
      // AiroBackgroundAudioMode.setEnabled is deliberately designed to
      // never throw — it swallows platform failures internally so its
      // static `isEnabled` always mirrors user intent (see
      // platform_player's background_audio_mode_test.dart, "setEnabled
      // swallows MissingPluginException"). That means a mock method
      // channel handler that throws can never actually surface an
      // exception to VideoPlayerWidget through the real service. To
      // genuinely exercise the widget's own try/catch + revert logic in
      // `_toggleAudioOnly`, we inject a failing `setAudioOnlyMode` via the
      // widget's test seam instead of going through the method channel.
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

      var successfulToggles = 0;
      var setAudioOnlyModeCalls = 0;

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
            playerBackgroundingCoordinatorProvider.overrideWithValue(
              SpyPlayerBackgroundingCoordinator(
                onManualAudioOnlyToggled: () {
                  successfulToggles++;
                },
              ),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: VideoPlayerWidget(
                setAudioOnlyMode: (enabled) async {
                  setAudioOnlyModeCalls++;
                  throw PlatformException(
                    code: 'test_failure',
                    message: 'simulated failure',
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final toggleFinder = find.byKey(const ValueKey('audio-only-toggle'));
      expect(toggleFinder, findsWidgets);

      Icon iconOf(Finder buttonFinder) => tester.widget<Icon>(
        find.descendant(of: buttonFinder, matching: find.byType(Icon)),
      );

      // Pre-tap: audio-only is off.
      expect(iconOf(toggleFinder).icon, Icons.hearing_disabled);
      expect(iconOf(toggleFinder).color, Colors.white);

      await tester.tap(toggleFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // The injected setter was actually invoked and actually threw.
      expect(setAudioOnlyModeCalls, equals(1));

      // The widget's local state reverted to its pre-tap value instead of
      // getting stuck on the optimistic value set before the failed call.
      expect(iconOf(toggleFinder).icon, Icons.hearing_disabled);
      expect(iconOf(toggleFinder).color, Colors.white);

      // The failed toggle never reached the coordinator.
      expect(successfulToggles, equals(0));

      // The real background-audio-mode channel was never touched — the
      // failure was injected purely via the widget's test seam — so its
      // static state is untouched by this failed attempt.
      expect(calls, isEmpty);
      expect(AiroBackgroundAudioMode.isEnabled, isFalse);
    },
  );
}

// Spy implementation for testing - tracks calls to coordinator methods
class SpyPlayerBackgroundingCoordinator
    implements PlayerBackgroundingCoordinator {
  final VoidCallback? onManualAudioOnlyToggled;

  SpyPlayerBackgroundingCoordinator({this.onManualAudioOnlyToggled});

  @override
  void manualAudioOnlyToggled(bool enabled) {
    onManualAudioOnlyToggled?.call();
  }

  @override
  Future<void> onLifecycleStateChanged(
    AppLifecycleState state,
    StreamingState streaming,
  ) async {}
}
