import 'dart:collection';

import 'package:equatable/equatable.dart';

/// What happened when a source's server was contacted.
///
/// Kept intentionally narrow — a sample never carries a request URL,
/// credential, or response body, only the categorical outcome and
/// timing. The `sourceId` is the ContentSourceConfig id, which is
/// non-secret by design (secrets live in ContentSourceCredentialStore
/// keyed on the same id).
enum ProviderHealthEventKind {
  /// HTTP request completed with a 2xx and a well-formed body.
  fetchSuccess,

  /// HTTP request failed (timeout, non-2xx, malformed body). The
  /// `failureCategory` should be one of the codes in
  /// [ProviderHealthFailureCategory].
  fetchFailure,

  /// Playback stall observed on a stream from this source (buffer
  /// underrun beyond a threshold — the threshold itself is a caller
  /// concern; the tracker only counts events).
  playbackStall,
}

/// Coarse buckets a fetch failure lands in. Kept short so a UI can
/// map each to a user-safe hint without exposing raw error text.
class ProviderHealthFailureCategory {
  const ProviderHealthFailureCategory._();

  /// Credentials rejected (401/403).
  static const String auth = 'auth';

  /// DNS/TLS/connect failure or timeout.
  static const String network = 'network';

  /// 5xx / server-side error.
  static const String server = 'server';

  /// Non-2xx that does not fit auth/server (400, 404, 429, etc).
  static const String client = 'client';

  /// Response body was 2xx but could not be parsed.
  static const String malformed = 'malformed';
}

/// One recorded observation of a source's health.
///
/// Redaction discipline: this class MUST NOT carry request URLs,
/// credentials, or server response bodies. The tracker's snapshots and
/// any UI reading them inherit that invariant.
class ProviderHealthSample extends Equatable {
  const ProviderHealthSample({
    required this.sourceId,
    required this.timestampUtc,
    required this.kind,
    this.latency,
    this.httpStatus,
    this.failureCategory,
  }) : assert(
         kind != ProviderHealthEventKind.fetchFailure ||
             failureCategory != null,
         'fetchFailure samples must set failureCategory',
       );

  factory ProviderHealthSample.fetchSuccess({
    required String sourceId,
    required DateTime timestampUtc,
    required Duration latency,
  }) => ProviderHealthSample(
    sourceId: sourceId,
    timestampUtc: timestampUtc,
    kind: ProviderHealthEventKind.fetchSuccess,
    latency: latency,
  );

  factory ProviderHealthSample.fetchFailure({
    required String sourceId,
    required DateTime timestampUtc,
    required String failureCategory,
    Duration? latency,
    int? httpStatus,
  }) => ProviderHealthSample(
    sourceId: sourceId,
    timestampUtc: timestampUtc,
    kind: ProviderHealthEventKind.fetchFailure,
    failureCategory: failureCategory,
    latency: latency,
    httpStatus: httpStatus,
  );

  factory ProviderHealthSample.playbackStall({
    required String sourceId,
    required DateTime timestampUtc,
  }) => ProviderHealthSample(
    sourceId: sourceId,
    timestampUtc: timestampUtc,
    kind: ProviderHealthEventKind.playbackStall,
  );

  final String sourceId;
  final DateTime timestampUtc;
  final ProviderHealthEventKind kind;
  final Duration? latency;
  final int? httpStatus;
  final String? failureCategory;

  @override
  List<Object?> get props => [
    sourceId,
    timestampUtc,
    kind,
    latency,
    httpStatus,
    failureCategory,
  ];
}

/// Coarse health class for a source.
///
/// The UI maps this to a badge (green/amber/red) plus a "likely-cause"
/// hint drawn from the most recent failure category. Callers should not
/// expose the raw failure rate or latency numbers directly — those are
/// tuning inputs, not user-facing.
enum ProviderHealthClass { unknown, green, amber, red }

/// Aggregate view of one source's recent samples.
class ProviderHealthSnapshot extends Equatable {
  const ProviderHealthSnapshot({
    required this.sourceId,
    required this.totalSamples,
    required this.healthClass,
    this.lastSuccessUtc,
    this.lastFailureUtc,
    this.p50Latency,
    this.p95Latency,
    this.failureRate = 0.0,
    this.recentFailureCategory,
    this.playbackStallCount = 0,
  });

  final String sourceId;
  final int totalSamples;
  final ProviderHealthClass healthClass;
  final DateTime? lastSuccessUtc;
  final DateTime? lastFailureUtc;
  final Duration? p50Latency;
  final Duration? p95Latency;

  /// Fraction of samples in the window that were `fetchFailure`, 0..1.
  final double failureRate;

  /// The `failureCategory` from the most recent `fetchFailure`, if any.
  /// Feeds the user-safe "likely cause" hint.
  final String? recentFailureCategory;

  final int playbackStallCount;

  @override
  List<Object?> get props => [
    sourceId,
    totalSamples,
    healthClass,
    lastSuccessUtc,
    lastFailureUtc,
    p50Latency,
    p95Latency,
    failureRate,
    recentFailureCategory,
    playbackStallCount,
  ];
}

/// In-memory ring-buffered health tracker.
///
/// One instance per app; caller records samples via [record] and reads
/// [snapshotFor] to derive a UI health class. Persistence and
/// cross-restart continuity are deliberately deferred — this slice-1
/// keeps the tracker pure and testable.
class ProviderHealthTracker {
  ProviderHealthTracker({int maxSamplesPerSource = 100})
    : assert(maxSamplesPerSource > 0),
      _maxSamplesPerSource = maxSamplesPerSource;

  final int _maxSamplesPerSource;
  final Map<String, Queue<ProviderHealthSample>> _samples = {};

  /// Adds [sample] to its source's ring buffer, evicting the oldest
  /// sample when the buffer is full.
  void record(ProviderHealthSample sample) {
    final buffer = _samples.putIfAbsent(sample.sourceId, Queue.new);
    buffer.addLast(sample);
    while (buffer.length > _maxSamplesPerSource) {
      buffer.removeFirst();
    }
  }

  ProviderHealthSnapshot snapshotFor(String sourceId) {
    final buffer = _samples[sourceId];
    if (buffer == null || buffer.isEmpty) {
      return ProviderHealthSnapshot(
        sourceId: sourceId,
        totalSamples: 0,
        healthClass: ProviderHealthClass.unknown,
      );
    }
    final samples = buffer.toList(growable: false);

    DateTime? lastSuccess;
    DateTime? lastFailure;
    String? recentFailureCategory;
    var failures = 0;
    var stalls = 0;
    final latencies = <Duration>[];
    for (final s in samples) {
      switch (s.kind) {
        case ProviderHealthEventKind.fetchSuccess:
          if (lastSuccess == null || s.timestampUtc.isAfter(lastSuccess)) {
            lastSuccess = s.timestampUtc;
          }
          if (s.latency != null) latencies.add(s.latency!);
        case ProviderHealthEventKind.fetchFailure:
          failures++;
          if (lastFailure == null || s.timestampUtc.isAfter(lastFailure)) {
            lastFailure = s.timestampUtc;
            recentFailureCategory = s.failureCategory;
          }
          if (s.latency != null) latencies.add(s.latency!);
        case ProviderHealthEventKind.playbackStall:
          stalls++;
      }
    }

    final fetchCount = samples
        .where(
          (s) =>
              s.kind == ProviderHealthEventKind.fetchSuccess ||
              s.kind == ProviderHealthEventKind.fetchFailure,
        )
        .length;
    final failureRate = fetchCount == 0 ? 0.0 : failures / fetchCount;
    final (p50, p95) = _percentiles(latencies);

    return ProviderHealthSnapshot(
      sourceId: sourceId,
      totalSamples: samples.length,
      healthClass: _classify(
        failureRate: failureRate,
        fetchCount: fetchCount,
        stallCount: stalls,
      ),
      lastSuccessUtc: lastSuccess,
      lastFailureUtc: lastFailure,
      p50Latency: p50,
      p95Latency: p95,
      failureRate: failureRate,
      recentFailureCategory: recentFailureCategory,
      playbackStallCount: stalls,
    );
  }

  /// Drops all samples for [sourceId]. Used when a source is removed
  /// or the user asks to reset its diagnostics.
  void clearFor(String sourceId) {
    _samples.remove(sourceId);
  }

  /// Drops every sample. Used by "Reset diagnostics" affordances.
  void clearAll() {
    _samples.clear();
  }

  /// Diagnostic-only view of the recorded sample count per source.
  int sampleCountFor(String sourceId) => _samples[sourceId]?.length ?? 0;
}

ProviderHealthClass _classify({
  required double failureRate,
  required int fetchCount,
  required int stallCount,
}) {
  if (fetchCount == 0 && stallCount == 0) return ProviderHealthClass.unknown;
  if (failureRate >= 0.5 || stallCount >= 5) return ProviderHealthClass.red;
  if (failureRate >= 0.15 || stallCount >= 2) return ProviderHealthClass.amber;
  return ProviderHealthClass.green;
}

(Duration?, Duration?) _percentiles(List<Duration> latencies) {
  if (latencies.isEmpty) return (null, null);
  final sorted = [...latencies]..sort();
  Duration at(double p) {
    final idx = ((sorted.length - 1) * p).round();
    return sorted[idx];
  }

  return (at(0.5), at(0.95));
}
