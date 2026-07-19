import 'package:flutter_test/flutter_test.dart';
import 'package:platform_player/platform_player.dart';

void main() {
  group('PlayerViewState', () {
    test('default state is idle/Auto/no-failover', () {
      const state = PlayerViewState();

      expect(state.playback, PlaybackState.idle);
      expect(state.liveState, LiveStreamState.unknown);
      expect(state.networkQuality, NetworkQuality.good);
      expect(state.bufferSeconds, 0);
      expect(state.qualityLabel, 'Auto');
      expect(state.title, '');
      expect(state.subtitle, '');
      expect(state.failover, isNull);
    });

    test('value equality holds for identical field values', () {
      const a = PlayerViewState(
        playback: PlaybackState.playing,
        liveState: LiveStreamState.live,
        networkQuality: NetworkQuality.excellent,
        bufferSeconds: 12,
        qualityLabel: '1080p',
        title: 'Channel 4',
        subtitle: 'News at Nine',
        failover: FailoverProgress(currentSource: 1, totalSources: 3),
      );
      const b = PlayerViewState(
        playback: PlaybackState.playing,
        liveState: LiveStreamState.live,
        networkQuality: NetworkQuality.excellent,
        bufferSeconds: 12,
        qualityLabel: '1080p',
        title: 'Channel 4',
        subtitle: 'News at Nine',
        failover: FailoverProgress(currentSource: 1, totalSources: 3),
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('value equality distinguishes differing fields', () {
      const a = PlayerViewState(title: 'Channel 4');
      const b = PlayerViewState(title: 'Channel 5');

      expect(a, isNot(equals(b)));
    });

    test('copyWith overrides only the given fields', () {
      const initial = PlayerViewState(
        playback: PlaybackState.buffering,
        bufferSeconds: 5,
        title: 'Original title',
        subtitle: 'Original subtitle',
      );

      final updated = initial.copyWith(bufferSeconds: 8);

      expect(updated.bufferSeconds, 8);
      // Unset fields must be preserved from the original instance.
      expect(updated.playback, PlaybackState.buffering);
      expect(updated.title, 'Original title');
      expect(updated.subtitle, 'Original subtitle');
      expect(updated.liveState, initial.liveState);
      expect(updated.networkQuality, initial.networkQuality);
      expect(updated.qualityLabel, initial.qualityLabel);
      expect(updated.failover, initial.failover);
    });

    test('copyWith preserves unset fields across every field', () {
      const initial = PlayerViewState(
        playback: PlaybackState.playing,
        liveState: LiveStreamState.dvrPlayback,
        networkQuality: NetworkQuality.fair,
        bufferSeconds: 20,
        qualityLabel: '720p',
        title: 'Some title',
        subtitle: 'Some subtitle',
        failover: FailoverProgress(currentSource: 2, totalSources: 4),
      );

      final copy = initial.copyWith();

      expect(copy, equals(initial));
    });

    test('copyWith can set failover to a new value', () {
      const initial = PlayerViewState();

      final withFailover = initial.copyWith(
        failover: const FailoverProgress(currentSource: 1, totalSources: 2),
      );

      expect(withFailover.failover, isNotNull);
      expect(withFailover.failover!.currentSource, 1);
      expect(withFailover.failover!.totalSources, 2);
    });

    test('copyWith clearFailover explicitly resets to null', () {
      const initial = PlayerViewState(
        failover: FailoverProgress(currentSource: 1, totalSources: 2),
      );

      final cleared = initial.copyWith(clearFailover: true);

      expect(cleared.failover, isNull);
    });
  });

  group('FailoverProgress', () {
    test('value equality holds for identical field values', () {
      const a = FailoverProgress(currentSource: 1, totalSources: 3);
      const b = FailoverProgress(currentSource: 1, totalSources: 3);

      expect(a, equals(b));
    });

    test('value equality distinguishes differing fields', () {
      const a = FailoverProgress(currentSource: 1, totalSources: 3);
      const b = FailoverProgress(currentSource: 2, totalSources: 3);

      expect(a, isNot(equals(b)));
    });
  });
}
