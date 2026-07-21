import 'package:airo_app/core/audio/tv_audio_service.dart';
import 'package:airo_app/main_tv.dart';
import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// #980: the TV entrypoint wires TvAudioHandler into the IPTV streaming
/// stack in both directions — the handler is exposed as the media-session
/// delegate (reporting), and its user-intent callbacks route notification
/// button presses back into the streaming service (control).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('TV entrypoint exposes TvAudioHandler as the media session delegate and '
      'routes notification controls back into the streaming service', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final mutableRepo = MutableXmltvCompactEpgRepository();
    final handler = TvAudioHandler();
    final streamingService = VideoPlayerStreamingService(
      engine: FakeAiroPlaybackEngine(),
    );
    addTearDown(streamingService.dispose);

    final container = ProviderContainer(
      overrides: [
        ...buildTvProviderOverrides(
          prefs: prefs,
          compactEpgRepository: createTvCompactEpgRepository(
            fallback: mutableRepo,
          ),
          mutableXmltvRepository: mutableRepo,
          tvAudioHandler: handler,
        ),
        iptvStreamingServiceProvider.overrideWithValue(streamingService),
      ],
    );
    addTearDown(container.dispose);

    // Reporting direction: the delegate provider resolves to the handler
    // and the integration provider attaches it to the service.
    expect(container.read(tvMediaSessionDelegateProvider), same(handler));
    container.read(tvIptvIntegrationProvider);
    expect(streamingService.mediaSessionDelegate, same(handler));

    // Control direction: notification buttons reach the streaming
    // service. FakeAiroPlaybackEngine starts idle; simulate playback,
    // then a notification pause must propagate. pumpEventQueue() between
    // steps models real notification-tap timing — taps never arrive in
    // the same microtask burst.
    await handler.playChannel('Test Channel', 'https://example.com/live.m3u8');
    await pumpEventQueue();

    await handler.pause();
    await pumpEventQueue();
    expect(streamingService.currentState.playbackState, PlaybackState.paused);

    await handler.play();
    await pumpEventQueue();
    expect(streamingService.currentState.playbackState, PlaybackState.playing);

    await handler.stop();
    await pumpEventQueue();
    expect(streamingService.currentState.playbackState, PlaybackState.idle);
  });

  test(
    'TV entrypoint without a TvAudioHandler leaves the delegate unset',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final mutableRepo = MutableXmltvCompactEpgRepository();

      final container = ProviderContainer(
        overrides: buildTvProviderOverrides(
          prefs: prefs,
          compactEpgRepository: createTvCompactEpgRepository(
            fallback: mutableRepo,
          ),
          mutableXmltvRepository: mutableRepo,
        ),
      );
      addTearDown(container.dispose);

      expect(container.read(tvMediaSessionDelegateProvider), isNull);
    },
  );
}
