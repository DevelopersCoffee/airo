import 'package:fake_async/fake_async.dart';
import 'package:feature_iptv/application/wakelock_playback_coordinator.dart';
import 'package:feature_iptv/domain/wakelock_debouncer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_player/platform_player.dart';

void main() {
  const videoChannel = IPTVChannel(
    id: 'news-1',
    name: 'City News Live',
    streamUrl: 'https://example.com/news.m3u8',
    group: 'News',
  );
  const audioChannel = IPTVChannel(
    id: 'radio-1',
    name: 'Radio One',
    streamUrl: 'https://example.com/radio.m3u8',
    group: 'Radio',
    isAudioOnly: true,
  );

  StreamingState playing(IPTVChannel channel) => StreamingState(
    playbackState: PlaybackState.playing,
    currentChannel: channel,
  );

  ({WakelockPlaybackCoordinator coordinator, List<String> calls}) build() {
    final calls = <String>[];
    final coordinator = WakelockPlaybackCoordinator(
      debouncer: WakelockDebouncer(settleDelay: const Duration(seconds: 2)),
      enable: () async => calls.add('enable'),
      disable: () async => calls.add('disable'),
    );
    return (coordinator: coordinator, calls: calls);
  }

  test('acquires wakelock once video playback holds steady', () {
    fakeAsync((async) {
      final (:coordinator, :calls) = build();

      coordinator.update(playing(videoChannel));
      expect(calls, isEmpty, reason: 'debounced — nothing before settle');

      async.elapse(const Duration(seconds: 2));
      expect(calls, ['enable']);
      expect(coordinator.isHeld, isTrue);
    });
  });

  test('releases wakelock when playback stops', () {
    fakeAsync((async) {
      final (:coordinator, :calls) = build();

      coordinator.update(playing(videoChannel));
      async.elapse(const Duration(seconds: 2));

      coordinator.update(StreamingState());
      async.elapse(const Duration(seconds: 2));

      expect(calls, ['enable', 'disable']);
      expect(coordinator.isHeld, isFalse);
    });
  });

  test('a transient stutter within the settle delay never flips the lock', () {
    fakeAsync((async) {
      final (:coordinator, :calls) = build();

      coordinator.update(playing(videoChannel));
      async.elapse(const Duration(seconds: 2));

      coordinator.update(
        StreamingState(
          playbackState: PlaybackState.buffering,
          currentChannel: videoChannel,
        ),
      );
      async.elapse(const Duration(seconds: 1));
      coordinator.update(playing(videoChannel));
      async.elapse(const Duration(seconds: 5));

      expect(calls, ['enable']);
    });
  });

  test('audio-only playback does not hold the wakelock', () {
    fakeAsync((async) {
      final (:coordinator, :calls) = build();

      coordinator.update(playing(audioChannel));
      async.elapse(const Duration(seconds: 5));

      expect(calls, isEmpty);
    });
  });

  test('dispose releases a held wakelock', () {
    fakeAsync((async) {
      final (:coordinator, :calls) = build();

      coordinator.update(playing(videoChannel));
      async.elapse(const Duration(seconds: 2));

      coordinator.dispose();
      async.flushMicrotasks();

      expect(calls, ['enable', 'disable']);
    });
  });
}
