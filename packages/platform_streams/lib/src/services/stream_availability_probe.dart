import 'dart:async';

/// The reachability classification for one user-supplied stream URL.
///
/// This deliberately says nothing about decoder compatibility. A successful
/// short HTTP response means the stream is reachable, not that every device can
/// decode it. Playback diagnostics remain the authority for that distinction.
enum StreamAvailability {
  available,
  unavailable,
  restricted,
  unverified,
  cancelled,
}

/// Redacted input for a stream reachability request.
///
/// [channelId] must be a stable application identifier. [streamUri] and
/// [headers] are transport-only: the batcher never serializes or logs them.
class StreamProbeRequest {
  StreamProbeRequest({
    required this.channelId,
    required this.streamUri,
    Map<String, String> headers = const {},
  }) : headers = Map.unmodifiable(headers);

  final String channelId;
  final Uri streamUri;
  final Map<String, String> headers;
}

/// Minimal response metadata required to classify a probe.
class StreamProbeHttpResponse {
  const StreamProbeHttpResponse({required this.statusCode});

  final int statusCode;
}

enum StreamProbeFailureKind { timeout, network, cancelled, unknown }

/// Transport-level failure with an explicit retry/cancellation classification.
class StreamProbeTransportFailure implements Exception {
  const StreamProbeTransportFailure(this.kind);

  const StreamProbeTransportFailure.timeout()
    : kind = StreamProbeFailureKind.timeout;

  const StreamProbeTransportFailure.network()
    : kind = StreamProbeFailureKind.network;

  const StreamProbeTransportFailure.cancelled()
    : kind = StreamProbeFailureKind.cancelled;

  final StreamProbeFailureKind kind;

  bool get isTransient =>
      kind == StreamProbeFailureKind.timeout ||
      kind == StreamProbeFailureKind.network;
}

/// Lets a UI or lifecycle owner stop a batch and any in-flight transport work.
class StreamProbeCancellation {
  bool _isCancelled = false;
  final List<void Function()> _listeners = [];

  bool get isCancelled => _isCancelled;

  void cancel() {
    if (_isCancelled) return;
    _isCancelled = true;
    for (final listener in List<void Function()>.from(_listeners)) {
      listener();
    }
    _listeners.clear();
  }

  void Function() onCancel(void Function() listener) {
    if (_isCancelled) {
      listener();
      return () {};
    }
    _listeners.add(listener);
    return () => _listeners.remove(listener);
  }
}

/// The platform-independent HTTP boundary.
///
/// The app selects the HTTP client appropriate for its target. This keeps the
/// batcher reusable while avoiding a new networking dependency in this package.
abstract interface class StreamProbeTransport {
  Future<StreamProbeHttpResponse> get(
    StreamProbeRequest request, {
    required StreamProbeCancellation cancellation,
  });
}

/// Public, redacted outcome for a single channel ID.
class StreamProbeResult {
  const StreamProbeResult({
    required this.channelId,
    required this.availability,
    required this.attempts,
    this.statusCode,
  });

  final String channelId;
  final StreamAvailability availability;
  final int attempts;
  final int? statusCode;

  bool get isRemovable => availability == StreamAvailability.unavailable;
}

/// Completed results from one bounded scan snapshot.
class StreamProbeBatchResult {
  StreamProbeBatchResult({
    required this.requestedCount,
    required Iterable<StreamProbeResult> results,
  }) : results = List.unmodifiable(results);

  final int requestedCount;
  final List<StreamProbeResult> results;

  int get completedCount => results.length;

  int get unavailableCount =>
      results.where((result) => result.isRemovable).length;

  bool get wasCancelled => completedCount < requestedCount;
}

/// Bounded, cancellable availability probing for user-supplied stream URLs.
///
/// The probe intentionally performs only transport work. It does not construct
/// media players, parse a manifest, persist URLs, or emit request data.
class StreamAvailabilityProbe {
  StreamAvailabilityProbe({required this.transport});

  final StreamProbeTransport transport;

  Future<StreamProbeResult> probe(
    StreamProbeRequest request, {
    StreamProbeCancellation? cancellation,
  }) async {
    final cancel = cancellation ?? StreamProbeCancellation();
    if (!_isHttp(request.streamUri)) {
      return StreamProbeResult(
        channelId: request.channelId,
        availability: StreamAvailability.unverified,
        attempts: 0,
      );
    }

    for (var attempt = 1; attempt <= 2; attempt++) {
      if (cancel.isCancelled) {
        return StreamProbeResult(
          channelId: request.channelId,
          availability: StreamAvailability.cancelled,
          attempts: attempt - 1,
        );
      }

      try {
        final response = await transport.get(request, cancellation: cancel);
        final availability = _availabilityForStatus(response.statusCode);
        if (availability == StreamAvailability.unavailable &&
            _isTransientStatus(response.statusCode) &&
            attempt == 1) {
          continue;
        }
        return StreamProbeResult(
          channelId: request.channelId,
          availability: availability,
          attempts: attempt,
          statusCode: response.statusCode,
        );
      } on StreamProbeTransportFailure catch (failure) {
        if (cancel.isCancelled ||
            failure.kind == StreamProbeFailureKind.cancelled) {
          return StreamProbeResult(
            channelId: request.channelId,
            availability: StreamAvailability.cancelled,
            attempts: attempt,
          );
        }
        if (failure.isTransient && attempt == 1) continue;
        return StreamProbeResult(
          channelId: request.channelId,
          availability: StreamAvailability.unavailable,
          attempts: attempt,
        );
      } catch (_) {
        return StreamProbeResult(
          channelId: request.channelId,
          availability: StreamAvailability.unavailable,
          attempts: attempt,
        );
      }
    }

    throw StateError('Stream probe attempts were exhausted unexpectedly.');
  }

  Future<StreamProbeBatchResult> probeAll(
    List<StreamProbeRequest> requests, {
    required int maxConcurrentRequests,
    StreamProbeCancellation? cancellation,
    void Function(StreamProbeResult result, int completedCount)? onResult,
  }) async {
    if (maxConcurrentRequests < 1) {
      throw ArgumentError.value(
        maxConcurrentRequests,
        'maxConcurrentRequests',
        'Must be at least one.',
      );
    }
    final cancel = cancellation ?? StreamProbeCancellation();
    final results = List<StreamProbeResult?>.filled(requests.length, null);
    var nextIndex = 0;
    var completedCount = 0;

    Future<void> worker() async {
      while (!cancel.isCancelled) {
        if (nextIndex >= requests.length) return;
        final index = nextIndex++;
        final result = await probe(requests[index], cancellation: cancel);
        if (result.availability == StreamAvailability.cancelled) return;
        results[index] = result;
        completedCount++;
        onResult?.call(result, completedCount);
      }
    }

    final workerCount = maxConcurrentRequests < requests.length
        ? maxConcurrentRequests
        : requests.length;
    await Future.wait<void>([
      for (var index = 0; index < workerCount; index++) worker(),
    ]);

    return StreamProbeBatchResult(
      requestedCount: requests.length,
      results: results.whereType<StreamProbeResult>(),
    );
  }

  bool _isHttp(Uri uri) => uri.scheme == 'http' || uri.scheme == 'https';

  StreamAvailability _availabilityForStatus(int statusCode) {
    if (statusCode >= 200 && statusCode < 300) {
      return StreamAvailability.available;
    }
    if (const {401, 403, 423, 426, 451}.contains(statusCode)) {
      return StreamAvailability.restricted;
    }
    return StreamAvailability.unavailable;
  }

  bool _isTransientStatus(int statusCode) =>
      statusCode >= 500 && statusCode < 600;
}
