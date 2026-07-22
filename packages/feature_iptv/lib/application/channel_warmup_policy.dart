import 'dart:math' as math;

import 'package:platform_channels/platform_channels.dart';
import 'package:platform_player/platform_player.dart';

class ChannelWarmupPlan {
  const ChannelWarmupPlan({
    required this.limit,
    required this.maxConcurrentRequests,
    required this.debounce,
  });

  final int limit;
  final int maxConcurrentRequests;
  final Duration debounce;

  bool get isEmpty => limit <= 0;
}

/// Chooses a bounded stream-health warmup size for the current interaction.
///
/// The plan is conservative while playback is loading or buffering because
/// probes share network capacity with the player open. As cache coverage
/// improves, the app can safely test a wider lookahead window because most
/// rows are served from memory and fewer network probes are needed.
ChannelWarmupPlan planChannelWarmup({
  required int totalChannelCount,
  required int candidateCount,
  required int cachedChannelCount,
  required PlaybackState playbackState,
  bool interactionCritical = false,
}) {
  if (totalChannelCount <= 0 || candidateCount <= 0) {
    return const ChannelWarmupPlan(
      limit: 0,
      maxConcurrentRequests: 1,
      debounce: Duration(milliseconds: 350),
    );
  }

  final coverage = (cachedChannelCount / totalChannelCount).clamp(0.0, 1.0);
  final isPlaybackBusy =
      playbackState == PlaybackState.loading ||
      playbackState == PlaybackState.buffering;
  final isPlaying = playbackState == PlaybackState.playing;

  if (interactionCritical) {
    final cap = isPlaybackBusy
        ? 10
        : coverage < 0.25
        ? 14
        : coverage < 0.75
        ? 20
        : 28;
    return ChannelWarmupPlan(
      limit: _boundedLimit(candidateCount, totalChannelCount, cap),
      maxConcurrentRequests: 1,
      debounce: Duration(milliseconds: isPlaybackBusy ? 450 : 180),
    );
  }

  if (totalChannelCount <= 60) {
    return ChannelWarmupPlan(
      limit: _boundedLimit(
        candidateCount,
        totalChannelCount,
        totalChannelCount,
      ),
      maxConcurrentRequests: isPlaying || isPlaybackBusy ? 1 : 3,
      debounce: const Duration(milliseconds: 220),
    );
  }

  if (isPlaybackBusy) {
    return ChannelWarmupPlan(
      limit: _boundedLimit(candidateCount, totalChannelCount, 18),
      maxConcurrentRequests: 1,
      debounce: const Duration(milliseconds: 450),
    );
  }

  if (isPlaying) {
    final cap = coverage < 0.25
        ? 30
        : coverage < 0.75
        ? 42
        : 60;
    return ChannelWarmupPlan(
      limit: _boundedLimit(candidateCount, totalChannelCount, cap),
      maxConcurrentRequests: coverage >= 0.75 ? 2 : 1,
      debounce: const Duration(milliseconds: 300),
    );
  }

  final cap = coverage < 0.25
      ? 48
      : coverage < 0.75
      ? 72
      : 96;
  return ChannelWarmupPlan(
    limit: _boundedLimit(candidateCount, totalChannelCount, cap),
    maxConcurrentRequests: 3,
    debounce: const Duration(milliseconds: 220),
  );
}

List<IPTVChannel> channelWarmupWindowAround({
  required IPTVChannel? currentChannel,
  required List<IPTVChannel> channels,
  int lookBehind = 4,
  int lookAhead = 12,
}) {
  if (currentChannel == null || channels.isEmpty) return const [];
  final currentIndex = channels.indexWhere(
    (channel) => channel.streamUrl == currentChannel.streamUrl,
  );
  if (currentIndex < 0) return const [];

  final result = <IPTVChannel>[];
  final seen = <String>{};

  void addIndex(int index) {
    final channel = channels[(index + channels.length) % channels.length];
    if (seen.add(channel.id)) result.add(channel);
  }

  addIndex(currentIndex);
  final distance = math.max(lookAhead, lookBehind);
  for (var offset = 1; offset <= distance; offset++) {
    if (offset <= lookAhead) addIndex(currentIndex + offset);
    if (offset <= lookBehind) addIndex(currentIndex - offset);
    if (seen.length >= channels.length) break;
  }
  return result;
}

int _boundedLimit(int candidateCount, int totalChannelCount, int cap) {
  return math.max(
    0,
    math.min(math.min(candidateCount, totalChannelCount), cap),
  );
}
