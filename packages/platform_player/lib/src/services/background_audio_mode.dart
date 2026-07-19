import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:flutter/services.dart';

/// Toggles audio-only playback (video surface torn down, audio keeps
/// decoding) and drives the OS lock-screen / notification media controls
/// ([MPNowPlayingInfoCenter] iOS, [MediaSession] Android) required whenever
/// audio plays in the background.
class AiroBackgroundAudioMode {
  AiroBackgroundAudioMode._();

  static MethodChannel _channel = const MethodChannel(
    'com.airo.player/background_audio_mode',
  );
  static bool _isEnabled = false;

  static bool get isEnabled => _isEnabled;

  static Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;
    try {
      await _channel.invokeMethod<void>('setEnabled', {'enabled': enabled});
    } on MissingPluginException {
      debugPrint('Background audio channel is unavailable on this host');
    } catch (error) {
      debugPrint('Background audio setEnabled error: $error');
    }
  }

  @visibleForTesting
  static void debugSetMethodChannel(MethodChannel channel) {
    _channel = channel;
  }

  @visibleForTesting
  static void debugReset() {
    _isEnabled = false;
  }
}
