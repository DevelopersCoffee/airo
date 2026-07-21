import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_player/platform_player.dart';

import 'iptv_providers.dart';
import 'vod_providers.dart';

/// VOD item selected for playback but not yet confirmed by the player.
///
/// The live player reports VOD playback through a synthetic [IPTVChannel]
/// with the same id, so the success recorder uses this marker to route the
/// first playing transition into VOD history instead of live recents.
final pendingVodHistoryItemProvider = StateProvider<VodItem?>((ref) => null);

/// Records recently watched entries only after playback reaches `playing`.
///
/// Selection-time writes pollute history when a stream fails before it starts.
/// Keeping this as a separate provider avoids an import cycle between the live
/// IPTV providers and VOD providers.
final recentlyWatchedRecorderProvider = Provider<void>((ref) {
  String? lastRecordedChannelId;
  var writeQueue = Future<void>.value();

  void enqueueWrite(Future<void> Function() write) {
    writeQueue = writeQueue.then((_) => write()).catchError((Object error) {
      debugPrint('[RecentlyWatchedRecorder] Failed to record playback: $error');
    });
    unawaited(writeQueue);
  }

  void recordIfPlaying(StreamingState state) {
    final channel = state.currentChannel;
    if (channel == null || state.playbackState != PlaybackState.playing) {
      return;
    }

    if (channel.id == lastRecordedChannelId) {
      return;
    }
    lastRecordedChannelId = channel.id;

    final pendingVod = ref.read(pendingVodHistoryItemProvider);
    if (pendingVod != null && pendingVod.id == channel.id) {
      ref.read(pendingVodHistoryItemProvider.notifier).state = null;
      enqueueWrite(() async {
        await ref.read(vodWatchHistoryStorageProvider).addToRecent(pendingVod);
        ref.invalidate(vodContinueWatchingProvider);
      });
      return;
    }

    enqueueWrite(() async {
      await ref.read(recentlyWatchedStorageProvider).addToRecent(channel);
      ref.invalidate(recentlyWatchedChannelsProvider);
    });
  }

  final subscription = ref
      .watch(streamingStateStreamProvider)
      .listen(recordIfPlaying);
  ref.onDispose(subscription.cancel);
  recordIfPlaying(ref.read(iptvStreamingServiceProvider).currentState);
});
