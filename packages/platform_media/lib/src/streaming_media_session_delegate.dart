/// Receives playback lifecycle notifications from
/// [VideoPlayerStreamingService] so a host application can publish them to
/// the OS media session (e.g. an `audio_service`-backed handler on
/// Android TV / Fire TV driving the lock-screen and notification controls).
///
/// This is a reporting-only contract: the delegate is told what the player
/// did — it never controls playback. Control flows the other way: the user
/// taps a notification button, and the host-side handler calls back into
/// the streaming service's own `pause()`/`resume()`/`stop()`. Keeping the
/// directions separate prevents delegate→handler→service recursion.
abstract class StreamingMediaSessionDelegate {
  /// A channel finished opening and transitioned to playing. [streamUrl] is
  /// the resolved URL actually handed to the playback engine.
  Future<void> onChannelStarted({
    required String channelName,
    required String streamUrl,
  });

  /// Playback was paused.
  Future<void> onPlaybackPaused();

  /// Playback resumed from a paused state.
  Future<void> onPlaybackResumed();

  /// Playback stopped and the session returned to idle.
  Future<void> onPlaybackStopped();
}
