import 'package:flutter_test/flutter_test.dart';
import 'package:platform_streams/platform_streams.dart';

void main() {
  test(
    'retries a transient failure once before marking a stream unavailable',
    () async {
      final transport = _FakeProbeTransport(
        responses: {
          'retry': [
            const StreamProbeTransportFailure.timeout(),
            const StreamProbeHttpResponse(statusCode: 503),
          ],
        },
      );
      final probe = StreamAvailabilityProbe(transport: transport);

      final result = await probe.probe(
        StreamProbeRequest(
          channelId: 'retry',
          streamUri: Uri.parse('https://streams.example/retry.m3u8'),
        ),
      );

      expect(result.availability, StreamAvailability.unavailable);
      expect(result.attempts, 2);
      expect(transport.requestedChannelIds, ['retry', 'retry']);
    },
  );

  test('keeps access-restricted streams out of the unavailable set', () async {
    final probe = StreamAvailabilityProbe(
      transport: _FakeProbeTransport(
        responses: {
          'restricted': [const StreamProbeHttpResponse(statusCode: 451)],
        },
      ),
    );

    final result = await probe.probe(
      StreamProbeRequest(
        channelId: 'restricted',
        streamUri: Uri.parse('https://streams.example/restricted.m3u8'),
      ),
    );

    expect(result.availability, StreamAvailability.restricted);
    expect(result.isRemovable, isFalse);
  });

  test('does not send unsupported stream schemes to the transport', () async {
    final transport = _FakeProbeTransport(responses: const {});
    final probe = StreamAvailabilityProbe(transport: transport);

    final result = await probe.probe(
      StreamProbeRequest(
        channelId: 'udp',
        streamUri: Uri.parse('udp://239.0.0.1:1234'),
      ),
    );

    expect(result.availability, StreamAvailability.unverified);
    expect(transport.requestedChannelIds, isEmpty);
  });

  test('limits batch probes to the supplied concurrency', () async {
    final transport = _FakeProbeTransport(
      responses: {
        for (final id in ['a', 'b', 'c'])
          id: [const StreamProbeHttpResponse(statusCode: 206)],
      },
      delay: const Duration(milliseconds: 20),
    );
    final probe = StreamAvailabilityProbe(transport: transport);

    final batch = await probe.probeAll([
      StreamProbeRequest(
        channelId: 'a',
        streamUri: Uri.parse('https://streams.example/a.m3u8'),
      ),
      StreamProbeRequest(
        channelId: 'b',
        streamUri: Uri.parse('https://streams.example/b.m3u8'),
      ),
      StreamProbeRequest(
        channelId: 'c',
        streamUri: Uri.parse('https://streams.example/c.m3u8'),
      ),
    ], maxConcurrentRequests: 2);

    expect(batch.completedCount, 3);
    expect(transport.peakConcurrentRequests, 2);
  });
}

class _FakeProbeTransport implements StreamProbeTransport {
  _FakeProbeTransport({required this.responses, this.delay = Duration.zero});

  final Map<String, List<Object>> responses;
  final Duration delay;
  final List<String> requestedChannelIds = [];
  var _inFlightRequests = 0;
  var peakConcurrentRequests = 0;

  @override
  Future<StreamProbeHttpResponse> get(
    StreamProbeRequest request, {
    required StreamProbeCancellation cancellation,
  }) async {
    requestedChannelIds.add(request.channelId);
    _inFlightRequests++;
    peakConcurrentRequests = peakConcurrentRequests < _inFlightRequests
        ? _inFlightRequests
        : peakConcurrentRequests;
    try {
      if (delay != Duration.zero) await Future<void>.delayed(delay);
      final response = responses[request.channelId]!.removeAt(0);
      if (response is StreamProbeTransportFailure) throw response;
      return response as StreamProbeHttpResponse;
    } finally {
      _inFlightRequests--;
    }
  }
}
