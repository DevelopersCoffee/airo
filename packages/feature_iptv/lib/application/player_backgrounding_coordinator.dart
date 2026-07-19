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

  /// Called by the manual audio-only toggle in the player controls.
  void manualAudioOnlyToggled(bool enabled) {
    _manualAudioOnly = enabled;
  }

  Future<void> onLifecycleStateChanged(
    AppLifecycleState state,
    StreamingState streaming,
  ) async {
    if (!streaming.isPlaying) return;

    if (state == AppLifecycleState.paused) {
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
