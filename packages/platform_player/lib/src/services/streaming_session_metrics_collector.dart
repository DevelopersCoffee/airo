// ignore_for_file: prefer_initializing_formals
import 'package:core_analytics/core_analytics.dart';

/// Pure accumulator that turns timestamped playback-lifecycle signals into
/// an [AiroStreamingSessionSummary] (requirements F7.1).
///
/// No I/O and no timers of its own — the caller reports each transition as
/// it happens. This lets the current Dart engine and a future native
/// (Media3/Kotlin) engine feed the same collector through whatever bridge
/// each uses.
class StreamingSessionMetricsCollector {
  StreamingSessionMetricsCollector({
    required String sessionId,
    required String activeSourceId,
    required String networkKey,
    DateTime Function()? now,
  }) : _sessionId = sessionId,
       _activeSourceId = activeSourceId,
       _networkKey = networkKey,
       _now = now ?? DateTime.now;

  /// Reservoir cap for throughput samples — keeps memory bounded on long
  /// sessions instead of growing with every sample reported.
  static const int _maxThroughputSamples = 256;

  final String _sessionId;
  final String _networkKey;
  final DateTime Function() _now;

  String _activeSourceId;
  DateTime? _sessionStartedAt;
  DateTime? _firstFrameAt;
  DateTime? _stallStartedAt;
  int _rebufferCount = 0;
  Duration _rebufferDuration = Duration.zero;
  int _sourceSwitchCount = 0;
  final List<double> _throughputSamplesKbps = [];

  void sessionStarted() {
    _sessionStartedAt ??= _now();
  }

  void firstFrameRendered() {
    _firstFrameAt ??= _now();
  }

  void stallStarted() {
    _stallStartedAt ??= _now();
  }

  void stallEnded() {
    final startedAt = _stallStartedAt;
    if (startedAt == null) return;
    _rebufferCount++;
    _rebufferDuration += _now().difference(startedAt);
    _stallStartedAt = null;
  }

  void throughputSampleKbps(double kbps) {
    if (kbps < 0) return;
    if (_throughputSamplesKbps.length >= _maxThroughputSamples) {
      _throughputSamplesKbps.removeAt(0);
    }
    _throughputSamplesKbps.add(kbps);
  }

  void sourceSwitched(String newActiveSourceId) {
    _sourceSwitchCount++;
    _activeSourceId = newActiveSourceId;
  }

  AiroStreamingSessionSummary sessionStopped() {
    final stoppedAt = _now();
    final startedAt = _sessionStartedAt ?? stoppedAt;
    final sessionDurationMs = stoppedAt.difference(startedAt).inMilliseconds;

    final ratio = sessionDurationMs > 0
        ? (_rebufferDuration.inMilliseconds / sessionDurationMs).clamp(0, 1)
        : 0.0;

    return AiroStreamingSessionSummary(
      sessionId: _sessionId,
      activeSourceId: _activeSourceId,
      networkKey: _networkKey,
      ttffMs: _firstFrameAt?.difference(startedAt).inMilliseconds,
      rebufferCount: _rebufferCount,
      rebufferDurationRatio: ratio.toDouble(),
      sourceSwitchCount: _sourceSwitchCount,
      throughputKbpsP50: _percentile(0.5),
      throughputKbpsP10: _percentile(0.1),
    );
  }

  double? _percentile(double p) {
    if (_throughputSamplesKbps.isEmpty) return null;
    final sorted = [..._throughputSamplesKbps]..sort();
    final index = ((sorted.length - 1) * p).round();
    return sorted[index];
  }
}
