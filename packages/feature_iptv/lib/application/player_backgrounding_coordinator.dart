import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_player/platform_player.dart';

import 'providers/iptv_providers.dart';

/// Decides what happens to live playback when the app is backgrounded:
/// PiP is attempted first, audio-only is the fallback (spec Goal 5). A
/// manual audio-only toggle (set before backgrounding) always wins and
/// skips the PiP attempt.
///
/// PiP entry must be *armed before* the user leaves the app: by the time
/// Flutter reports `AppLifecycleState.paused`, the Android Activity is no
/// longer resumed and `enterPictureInPictureMode()` throws
/// `IllegalStateException`. So while playback is active this coordinator
/// arms native auto-enter ([AiroNativePictureInPicture.setAutoEnterEnabled],
/// which maps to `PictureInPictureParams.setAutoEnterEnabled` on API 31+
/// and an `onUserLeaveHint` entry on API 26–30). The paused handler then
/// only confirms PiP engaged ([AiroNativePictureInPicture.isActive]) or
/// falls back to audio-only.
class PlayerBackgroundingCoordinator {
  PlayerBackgroundingCoordinator({
    Future<bool> Function()? isSupported,
    Future<bool> Function()? requestEnter,
    Future<bool> Function()? isActive,
    Future<void> Function(bool enabled)? setAutoEnter,
    Future<void> Function(bool enabled)? setAudioOnly,
  }) : _isSupported = isSupported ?? AiroNativePictureInPicture.isSupported,
       _requestEnter = requestEnter ?? AiroNativePictureInPicture.requestEnter,
       _isActive = isActive ?? AiroNativePictureInPicture.isActive,
       _setAutoEnter =
           setAutoEnter ?? AiroNativePictureInPicture.setAutoEnterEnabled,
       _setAudioOnly = setAudioOnly ?? AiroBackgroundAudioMode.setEnabled;

  final Future<bool> Function() _isSupported;
  final Future<bool> Function() _requestEnter;
  final Future<bool> Function() _isActive;
  final Future<void> Function(bool enabled) _setAutoEnter;
  final Future<void> Function(bool enabled) _setAudioOnly;

  bool _manualAudioOnly = false;
  bool _autoAudioOnlyActive = false;
  bool _autoEnterArmed = false;
  bool _lastPlaying = false;
  Future<void> _pending = Future<void>.value();

  /// Called by the manual audio-only toggle in the player controls.
  void manualAudioOnlyToggled(bool enabled) {
    _manualAudioOnly = enabled;
    unawaited(_syncAutoEnterArming());
  }

  /// Called when the streaming state changes. Arms native auto-enter PiP
  /// while playback is active (and no manual audio-only override) so a
  /// Home press enters PiP natively; disarms when playback stops.
  void onStreamingStateChanged(StreamingState streaming) {
    _lastPlaying = streaming.isPlaying;
    unawaited(_syncAutoEnterArming());
  }

  Future<void> _syncAutoEnterArming() async {
    final shouldArm =
        _lastPlaying && !_manualAudioOnly && await _isSupported();
    if (shouldArm == _autoEnterArmed) return;
    _autoEnterArmed = shouldArm;
    await _setAutoEnter(shouldArm);
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
    _lastPlaying = streaming.isPlaying;
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

    // The normal path: native auto-enter (armed while playback started)
    // already put the app into PiP by the time this paused callback runs.
    if (await _isActive()) return;

    // Last-chance attempt for hosts without native auto-enter (e.g. iOS,
    // where AVPictureInPictureController can still start from here).
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
      // The single native PiP state-change subscription for the whole
      // session, mirrored into pictureInPictureActiveProvider so any widget
      // can switch to a video-only layout while PiP is up (#1002). Owning
      // it here (session scope) instead of in individual widgets avoids
      // competing subscribers on AiroNativePictureInPicture's single
      // handler slot.
      AiroNativePictureInPicture.setStateChangeHandler((isActive) {
        ref.read(pictureInPictureActiveProvider.notifier).state = isActive;
      });
      ref.onDispose(
        () => AiroNativePictureInPicture.setStateChangeHandler(null),
      );
      ref.listen<AppLifecycleState>(appLifecycleStateProvider, (
        previous,
        next,
      ) {
        final streaming = ref.read(streamingStateProvider).value;
        if (streaming != null) {
          coordinator.onLifecycleStateChanged(next, streaming);
        }
      });
      // Arms/disarms native auto-enter PiP as playback starts/stops — PiP
      // entry must be armed before the user backgrounds the app (see the
      // coordinator's class doc).
      ref.listen<AsyncValue<StreamingState>>(streamingStateProvider, (
        previous,
        next,
      ) {
        final streaming = next.value;
        if (streaming != null) {
          coordinator.onStreamingStateChanged(streaming);
        }
      });
      return coordinator;
    });
