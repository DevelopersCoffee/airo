import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart';

/// Method-channel bridge to the receiver-side native streaming engine
/// (Media3/Kotlin, `tv` flavor only — see SPEC.md AD-1/AD-5).
///
/// Mirrors [AiroNativePictureInPicture]'s shape: a static wrapper around a
/// const [MethodChannel], degrading to a safe default on hosts with no
/// platform implementation (phone/Coins flavors, non-Android platforms)
/// instead of throwing.
class AiroStreamingEngineChannel {
  AiroStreamingEngineChannel._();

  static const MethodChannel _channel = MethodChannel(
    'com.airo.player/streaming_engine',
  );

  /// Round-trip proof that the native plugin is registered and responding.
  /// Returns `false` — never throws — when no platform implementation
  /// exists (phone/Coins flavors) or the call otherwise fails.
  static Future<bool> ping() async {
    try {
      return await _channel.invokeMethod<bool>('ping') ?? false;
    } on MissingPluginException {
      debugPrint('Streaming engine channel is unavailable on this host');
      return false;
    } catch (error) {
      debugPrint('Streaming engine ping error: $error');
      return false;
    }
  }

  /// F4.2.2 — open and hold connections to [hosts] while the user browses
  /// the channel grid, before playback intent exists. Best-effort and
  /// fire-and-forget from the caller's perspective: never throws on hosts
  /// without a platform implementation or any other failure.
  static Future<void> preWarm(List<String> hosts) async {
    try {
      await _channel.invokeMethod<void>('preWarm', {'hosts': hosts});
    } on MissingPluginException {
      debugPrint('Streaming engine channel is unavailable on this host');
    } catch (error) {
      debugPrint('Streaming engine preWarm error: $error');
    }
  }
}
