import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_player/platform_player.dart';
import 'package:feature_iptv/application/player_backgrounding_coordinator.dart';

StreamingState _playingState({bool audioOnlyChannel = false}) => StreamingState(
  playbackState: PlaybackState.playing,
  currentChannel: IPTVChannel(
    id: 'c1',
    name: 'Test',
    streamUrl: 'https://example.com/s.m3u8',
    isAudioOnly: audioOnlyChannel,
  ),
);

void main() {
  group('PlayerBackgroundingCoordinator', () {
    test('backgrounding with no prior manual toggle tries PiP first', () async {
      var requestEnterCalled = false;
      final coordinator = PlayerBackgroundingCoordinator(
        isSupported: () async => true,
        requestEnter: () async {
          requestEnterCalled = true;
          return true;
        },
        setAudioOnly: (_) async => fail('audio-only should not be set'),
      );

      await coordinator.onLifecycleStateChanged(
        AppLifecycleState.paused,
        _playingState(),
      );

      expect(requestEnterCalled, isTrue);
    });

    test('PiP unsupported falls back to audio-only', () async {
      bool? audioOnlySet;
      final coordinator = PlayerBackgroundingCoordinator(
        isSupported: () async => false,
        requestEnter: () async => fail('requestEnter should not be called'),
        setAudioOnly: (enabled) async => audioOnlySet = enabled,
      );

      await coordinator.onLifecycleStateChanged(
        AppLifecycleState.paused,
        _playingState(),
      );

      expect(audioOnlySet, isTrue);
    });

    test('PiP denied at request time falls back to audio-only', () async {
      bool? audioOnlySet;
      final coordinator = PlayerBackgroundingCoordinator(
        isSupported: () async => true,
        requestEnter: () async => false,
        setAudioOnly: (enabled) async => audioOnlySet = enabled,
      );

      await coordinator.onLifecycleStateChanged(
        AppLifecycleState.paused,
        _playingState(),
      );

      expect(audioOnlySet, isTrue);
    });

    test('prior manual audio-only toggle skips PiP entirely', () async {
      var requestEnterCalled = false;
      bool? audioOnlySet;
      final coordinator = PlayerBackgroundingCoordinator(
        isSupported: () async => true,
        requestEnter: () async {
          requestEnterCalled = true;
          return true;
        },
        setAudioOnly: (enabled) async => audioOnlySet = enabled,
      );

      coordinator.manualAudioOnlyToggled(true);
      await coordinator.onLifecycleStateChanged(
        AppLifecycleState.paused,
        _playingState(),
      );

      expect(requestEnterCalled, isFalse);
      expect(audioOnlySet, isTrue);
    });

    test('not playing: backgrounding does nothing', () async {
      var called = false;
      final coordinator = PlayerBackgroundingCoordinator(
        isSupported: () async {
          called = true;
          return true;
        },
        requestEnter: () async => true,
        setAudioOnly: (_) async {},
      );

      await coordinator.onLifecycleStateChanged(
        AppLifecycleState.paused,
        StreamingState(playbackState: PlaybackState.idle),
      );

      expect(called, isFalse);
    });

    test(
      'resuming from auto audio-only clears audio-only automatically',
      () async {
        final audioOnlyCalls = <bool>[];
        final coordinator = PlayerBackgroundingCoordinator(
          isSupported: () async => false,
          requestEnter: () async => false,
          setAudioOnly: (enabled) async => audioOnlyCalls.add(enabled),
        );

        await coordinator.onLifecycleStateChanged(
          AppLifecycleState.paused,
          _playingState(),
        );
        await coordinator.onLifecycleStateChanged(
          AppLifecycleState.resumed,
          _playingState(),
        );

        expect(audioOnlyCalls, [true, false]);
      },
    );

    test(
      'resuming after a manual audio-only toggle leaves it enabled',
      () async {
        final audioOnlyCalls = <bool>[];
        final coordinator = PlayerBackgroundingCoordinator(
          isSupported: () async => true,
          requestEnter: () async => true,
          setAudioOnly: (enabled) async => audioOnlyCalls.add(enabled),
        );

        coordinator.manualAudioOnlyToggled(true);
        await coordinator.onLifecycleStateChanged(
          AppLifecycleState.paused,
          _playingState(),
        );
        await coordinator.onLifecycleStateChanged(
          AppLifecycleState.resumed,
          _playingState(),
        );

        expect(audioOnlyCalls, [true]);
      },
    );
  });
}
