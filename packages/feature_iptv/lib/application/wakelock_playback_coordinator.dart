import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_player/platform_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../domain/wakelock_debouncer.dart';
import 'providers/iptv_providers.dart';

/// Holds the OS wakelock while video is actually playing, independent of any
/// player widget's lifetime.
///
/// The previous widget-level approach released the wakelock whenever
/// [VideoPlayerWidget] was disposed — which happens when the featured player
/// scrolls out of a lazy viewport or playback continues under the mini
/// player — so the display slept mid-stream.
class WakelockPlaybackCoordinator {
  WakelockPlaybackCoordinator({
    WakelockDebouncer? debouncer,
    Future<void> Function()? enable,
    Future<void> Function()? disable,
  }) : _debouncer = debouncer ?? WakelockDebouncer(),
       _enable = enable ?? WakelockPlus.enable,
       _disable = disable ?? WakelockPlus.disable;

  final WakelockDebouncer _debouncer;
  final Future<void> Function() _enable;
  final Future<void> Function() _disable;

  bool _held = false;

  @visibleForTesting
  bool get isHeld => _held;

  /// Video actively playing on a non-audio-only channel holds the wakelock.
  static bool shouldHoldWakelock(StreamingState state) {
    final channel = state.currentChannel;
    return state.isPlaying && channel != null && !channel.isAudioOnly;
  }

  void update(StreamingState state) {
    _debouncer.update(
      current: _held,
      target: shouldHoldWakelock(state),
      onSettled: (target) => unawaited(target ? _acquire() : _release()),
    );
  }

  Future<void> _acquire() async {
    if (_held) return;
    try {
      await _enable();
      _held = true;
    } catch (e) {
      debugPrint('Failed to enable wakelock: $e');
    }
  }

  Future<void> _release() async {
    if (!_held) return;
    try {
      await _disable();
      _held = false;
    } catch (e) {
      debugPrint('Failed to disable wakelock: $e');
    }
  }

  void dispose() {
    _debouncer.cancel();
    unawaited(_release());
  }
}

final wakelockPlaybackCoordinatorProvider =
    Provider<WakelockPlaybackCoordinator>((ref) {
      final coordinator = WakelockPlaybackCoordinator();
      ref.onDispose(coordinator.dispose);
      ref.listen(streamingStateProvider, (previous, next) {
        final state = next.value;
        if (state != null) coordinator.update(state);
      });
      return coordinator;
    });
