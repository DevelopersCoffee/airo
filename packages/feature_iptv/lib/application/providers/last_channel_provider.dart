import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_player/platform_player.dart';

import 'iptv_providers.dart';

const String iptvLastChannelKey = 'iptv_last_channel';

IPTVChannel? findResumeChannel({
  required String? lastChannelId,
  required List<IPTVChannel> channels,
}) {
  if (lastChannelId == null) return null;

  for (final channel in channels) {
    if (channel.id == lastChannelId) return channel;
  }
  return null;
}

class LastChannelRecorder extends StateNotifier<String?> {
  LastChannelRecorder(this._ref) : super(null) {
    final subscription = _ref
        .watch(streamingStateStreamProvider)
        .listen(_recordCurrentChannel);
    _ref.onDispose(subscription.cancel);
    _recordCurrentChannel(
      _ref.read(iptvStreamingServiceProvider).currentState,
    );
  }

  final Ref _ref;

  void _recordCurrentChannel(StreamingState streamingState) {
    final channel = streamingState.currentChannel;
    if (channel == null || channel.id == state) return;
    state = channel.id;
    unawaited(_persist(channel.id));
  }

  Future<void> _persist(String channelId) async {
    try {
      await _ref
          .read(sharedPreferencesProvider)
          .setString(iptvLastChannelKey, channelId);
    } catch (_) {
      // Local preference failures must not affect playback.
    }
  }
}

final lastChannelRecorderProvider =
    StateNotifierProvider<LastChannelRecorder, String?>(
      (ref) => LastChannelRecorder(ref),
    );

final resumeChannelProvider = FutureProvider<IPTVChannel?>((ref) async {
  final lastChannelId = ref
      .watch(sharedPreferencesProvider)
      .getString(iptvLastChannelKey);
  if (lastChannelId == null) return null;

  final channels = await ref.watch(iptvChannelsProvider.future);
  return findResumeChannel(lastChannelId: lastChannelId, channels: channels);
});
