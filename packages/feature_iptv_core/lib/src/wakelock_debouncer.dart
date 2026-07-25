import 'dart:async';

/// Debounces a boolean playback signal so a single transient flip doesn't
/// trigger a guarded action — only a target that holds steady for
/// [settleDelay] invokes [onSettled].
///
/// Built for [VideoPlayerWidget]'s wakelock handling: the 1s buffer-monitor
/// timer in `video_player_streaming_service.dart` can flip
/// `StreamingState.isPlaying` to false for a single tick on a network
/// stutter, and without debouncing that toggles the OS wakelock on every
/// stutter.
class WakelockDebouncer {
  WakelockDebouncer({this.settleDelay = const Duration(seconds: 2)});

  final Duration settleDelay;
  bool? _pendingTarget;
  Timer? _timer;

  /// Call on every state observation.
  ///
  /// [current] is the caller's ground truth of what's currently applied;
  /// [target] is what the latest observation wants. [onSettled] fires only
  /// once [target] has been the requested value continuously (no
  /// intervening call with a different target) for [settleDelay].
  void update({
    required bool current,
    required bool target,
    required void Function(bool target) onSettled,
  }) {
    if (target == current) {
      cancel();
      return;
    }
    if (_pendingTarget == target) return;

    _pendingTarget = target;
    _timer?.cancel();
    _timer = Timer(settleDelay, () {
      _timer = null;
      _pendingTarget = null;
      onSettled(target);
    });
  }

  /// Cancels any pending settle timer without invoking [onSettled].
  void cancel() {
    _timer?.cancel();
    _timer = null;
    _pendingTarget = null;
  }
}
