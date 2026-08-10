import 'package:flutter/services.dart';
import 'package:platform_player/platform_player.dart';

/// Receiver playback phase stream (SPEC.md AD-1/AD-5, Phase 2 Task 5).
///
/// Deliberately reuses [AiroPlaybackEnginePhase] from `platform_player`
/// rather than inventing a parallel enum — downstream code (e.g. Phase 1's
/// `StreamingSessionMetricsCollector`) can eventually consume either
/// engine's phase stream uniformly.
class AiroStreamingEngineState {
  AiroStreamingEngineState._();

  static const EventChannel _channel = EventChannel(
    'com.airo.player/streaming_engine/state',
  );

  /// Native phase transitions, mapped onto [AiroPlaybackEnginePhase]. An
  /// unrecognized native stableId degrades to [AiroPlaybackEnginePhase
  /// .unavailable] rather than throwing — a newer native build's phase
  /// vocabulary must never crash an older Dart client.
  static Stream<AiroPlaybackEnginePhase> get phaseStream {
    return _channel.receiveBroadcastStream().map((event) {
      final stableId = event as String;
      for (final phase in AiroPlaybackEnginePhase.values) {
        if (phase.stableId == stableId) return phase;
      }
      return AiroPlaybackEnginePhase.unavailable;
    });
  }
}
