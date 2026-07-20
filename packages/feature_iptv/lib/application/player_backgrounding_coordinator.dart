import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_player/platform_player.dart';

import 'providers/iptv_providers.dart';

/// Decides what happens to live playback when the app is backgrounded:
/// PiP is attempted first, audio-only is the fallback (spec Goal 5). A
/// manual audio-only toggle (set before backgrounding) always wins and
/// skips the PiP attempt.
class PlayerBackgroundingCoordinator {
  PlayerBackgroundingCoordinator({
    Future<bool> Function()? isSupported,
    Future<bool> Function()? requestEnter,
    Future<void> Function(bool enabled)? setAudioOnly,
  }) : _isSupported = isSupported ?? AiroNativePictureInPicture.isSupported,
       _requestEnter = requestEnter ?? AiroNativePictureInPicture.requestEnter,
       _setAudioOnly = setAudioOnly ?? AiroBackgroundAudioMode.setEnabled;

  final Future<bool> Function() _isSupported;
  final Future<bool> Function() _requestEnter;
  final Future<void> Function(bool enabled) _setAudioOnly;

  bool _manualAudioOnly = false;
  bool _autoAudioOnlyActive = false;
  Future<void> _pending = Future<void>.value();

  /// Called by the manual audio-only toggle in the player controls.
  void manualAudioOnlyToggled(bool enabled) {
    _manualAudioOnly = enabled;
  }

  /// Serializes lifecycle decisions so overlapping calls (e.g. a rapid
  /// paused -> resumed flicker) never run concurrently. Without this, a
  /// `resumed` call could observe `_autoAudioOnlyActive == false` and no-op
  /// while an earlier, still in-flight `paused` call later sets it to
  /// `true`, stranding the app in audio-only after it's already back in the
  /// foreground.
  Future<void> onLifecycleStateChanged(
    AppLifecycleState state,
    StreamingState streaming,
  ) {
    final result = _pending.then((_) => _process(state, streaming));
    // Keep the chain alive even if a call throws, without swallowing the
    // error for the original caller (who awaits `result`, not `_pending`).
    _pending = result.catchError((_) {});
    return result;
  }

  Future<void> _process(
    AppLifecycleState state,
    StreamingState streaming,
  ) async {
    if (state == AppLifecycleState.paused) {
      // Only entering the background requires active playback; resuming
      // must always run so a stuck auto audio-only state can be cleared
      // even if playback stopped (error, lock-screen pause, buffering
      // timeout, playlist end) while backgrounded.
      if (!streaming.isPlaying) return;
      await _handleBackgrounding();
    } else if (state == AppLifecycleState.resumed) {
      await _handleResume();
    }
  }

  Future<void> _handleBackgrounding() async {
    if (_manualAudioOnly) {
      await _setAudioOnly(true);
      return;
    }

    if (await _isSupported() && await _requestEnter()) {
      return;
    }

    _autoAudioOnlyActive = true;
    await _setAudioOnly(true);
  }

  Future<void> _handleResume() async {
    if (_autoAudioOnlyActive) {
      _autoAudioOnlyActive = false;
      await _setAudioOnly(false);
    }
    // Manual audio-only persists across resume until the user toggles it
    // off themselves.
  }
}

final playerBackgroundingCoordinatorProvider =
    Provider<PlayerBackgroundingCoordinator>((ref) {
      final coordinator = PlayerBackgroundingCoordinator();
      ref.listen<AppLifecycleState>(appLifecycleStateProvider, (
        previous,
        next,
      ) {
        final streaming = ref.read(streamingStateProvider).value;
        if (streaming != null) {
          coordinator.onLifecycleStateChanged(next, streaming);
        }
      });
      return coordinator;
    });
