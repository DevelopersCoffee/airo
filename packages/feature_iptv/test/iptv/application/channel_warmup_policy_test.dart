import 'package:feature_iptv/application/channel_warmup_policy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_player/platform_player.dart';

void main() {
  test('keeps interaction-critical warmup small while playback is busy', () {
    final plan = planChannelWarmup(
      totalChannelCount: 5000,
      candidateCount: 80,
      cachedChannelCount: 0,
      playbackState: PlaybackState.loading,
      interactionCritical: true,
    );

    expect(plan.limit, 10);
    expect(plan.maxConcurrentRequests, 1);
    expect(plan.debounce, const Duration(milliseconds: 450));
  });

  test('widens browse warmup as stream-health cache coverage improves', () {
    final cold = planChannelWarmup(
      totalChannelCount: 5000,
      candidateCount: 100,
      cachedChannelCount: 0,
      playbackState: PlaybackState.playing,
    );
    final warm = planChannelWarmup(
      totalChannelCount: 5000,
      candidateCount: 100,
      cachedChannelCount: 4000,
      playbackState: PlaybackState.playing,
    );

    expect(cold.limit, 30);
    expect(cold.maxConcurrentRequests, 1);
    expect(warm.limit, 60);
    expect(warm.maxConcurrentRequests, 2);
  });

  test('builds a deduped nearby channel window around the current channel', () {
    final channels = List<IPTVChannel>.generate(
      6,
      (index) => IPTVChannel(
        id: 'channel-$index',
        name: 'Channel $index',
        streamUrl: 'https://example.com/$index.m3u8',
      ),
    );

    final window = channelWarmupWindowAround(
      currentChannel: channels[2],
      channels: channels,
      lookBehind: 2,
      lookAhead: 3,
    );

    expect(window.map((channel) => channel.id), [
      'channel-2',
      'channel-3',
      'channel-1',
      'channel-4',
      'channel-0',
      'channel-5',
    ]);
  });
}
