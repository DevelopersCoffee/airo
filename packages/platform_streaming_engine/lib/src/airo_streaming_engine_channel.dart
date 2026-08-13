import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart';

/// Outcome of a shadow-fetch probe (F4.3.2/F4.4.3) — mirrors the native
/// `AiroShadowFetchResult` sealed class exactly, one Dart type per status.
sealed class AiroShadowFetchOutcome {
  const AiroShadowFetchOutcome();
}

/// The probe completed and measured sustained throughput.
class AiroShadowFetchMeasured extends AiroShadowFetchOutcome {
  const AiroShadowFetchMeasured(this.throughputKbps);

  final double throughputKbps;
}

/// The probe failed — network error, non-2xx response, or an
/// unrecognized/no-platform-implementation host, folded into the same
/// shape so callers have one failure path to handle.
class AiroShadowFetchFailed extends AiroShadowFetchOutcome {
  const AiroShadowFetchFailed(this.reason);

  final String reason;
}

/// The native shadow-fetch limiter (F4.4.8 — max one concurrent probe)
/// rejected this call; the network was never touched.
class AiroShadowFetchBusy extends AiroShadowFetchOutcome {
  const AiroShadowFetchBusy();
}

/// Outcome of a `switchSource` call (F4.4.5/F4.4.6, splice-on-keyframe) —
/// mirrors the native `AiroSpliceOutcome` enum exactly, one Dart type
/// per status. Replaces the v1 basic-swap's plain `bool` (which could
/// only say "did a player exist," not "was the swap actually clean").
sealed class AiroSwitchSourceOutcome {
  const AiroSwitchSourceOutcome();
}

/// The swap landed on a splice-safe point (HLS segment boundary, or a
/// confirmed PAT/PMT/IDR chain for raw TS) within the deadline.
class AiroSwitchSourceSpliced extends AiroSwitchSourceOutcome {
  const AiroSwitchSourceSpliced();
}

/// No splice-safe point was found within the 3s deadline; the native
/// side fell back to a brief mute-and-cut swap instead (the spec's own
/// fallback, not a failure).
class AiroSwitchSourceFellBackToMuteCut extends AiroSwitchSourceOutcome {
  const AiroSwitchSourceFellBackToMuteCut();
}

/// No live player existed on the native side to act on, no platform
/// implementation is registered for this host, or the call otherwise
/// failed. Also the safe default for any unrecognized status string —
/// forward compatible with a native-side outcome this build doesn't
/// know about yet, without throwing.
class AiroSwitchSourceFailed extends AiroSwitchSourceOutcome {
  const AiroSwitchSourceFailed();
}

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

  /// F4.3.2/F4.4.3 — shadow-fetch [url] without disturbing playback.
  /// Never throws: any failure (network, no platform implementation,
  /// unexpected error) degrades to [AiroShadowFetchFailed] rather than
  /// propagating an exception to the caller.
  static Future<AiroShadowFetchOutcome> shadowFetch(String url) async {
    try {
      final raw = await _channel.invokeMapMethod<String, Object?>(
        'shadowFetch',
        {'url': url},
      );
      return _parseShadowFetchResult(raw);
    } on MissingPluginException {
      debugPrint('Streaming engine channel is unavailable on this host');
      return const AiroShadowFetchFailed('unavailable');
    } catch (error) {
      debugPrint('Streaming engine shadowFetch error: $error');
      return AiroShadowFetchFailed(error.toString());
    }
  }

  static AiroShadowFetchOutcome _parseShadowFetchResult(Map<String, Object?>? raw) {
    switch (raw?['status']) {
      case 'measured':
        return AiroShadowFetchMeasured((raw!['throughputKbps'] as num).toDouble());
      case 'busy':
        return const AiroShadowFetchBusy();
      case 'failed':
        return AiroShadowFetchFailed(raw!['reason'] as String? ?? 'unknown');
      default:
        return const AiroShadowFetchFailed('malformed platform response');
    }
  }

  /// F4.4.5/F4.4.6 — switch the active player to [url], waiting for a
  /// splice-safe point (bounded by the native side's 3s deadline) before
  /// swapping. Never throws — any failure (network, no platform
  /// implementation, unexpected error) degrades to
  /// [AiroSwitchSourceFailed] rather than propagating an exception.
  static Future<AiroSwitchSourceOutcome> switchSource(String url) async {
    try {
      final status = await _channel.invokeMethod<String>('switchSource', {
        'url': url,
      });
      return _parseSwitchSourceOutcome(status);
    } on MissingPluginException {
      debugPrint('Streaming engine channel is unavailable on this host');
      return const AiroSwitchSourceFailed();
    } catch (error) {
      debugPrint('Streaming engine switchSource error: $error');
      return const AiroSwitchSourceFailed();
    }
  }

  static AiroSwitchSourceOutcome _parseSwitchSourceOutcome(String? status) {
    switch (status) {
      case 'spliced':
        return const AiroSwitchSourceSpliced();
      case 'fellBackToMuteCut':
        return const AiroSwitchSourceFellBackToMuteCut();
      default:
        return const AiroSwitchSourceFailed();
    }
  }
}
