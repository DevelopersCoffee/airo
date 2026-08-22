import 'dart:async';

import 'package:feature_mind/src/agent_chat/domain/services/research/research_http.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final baseUri = Uri.parse('https://search.home.example/search');

  test('fetch rejects a redirect outside the configured origin', () async {
    final transport = _SequenceTransport([
      _response(statusCode: 302, location: 'https://evil.example/redirected'),
    ]);
    final client = _configuredClient(baseUri, transport: transport.call);

    await expectLater(
      client.get(baseUri),
      throwsA(isA<ResearchHttpException>()),
    );
    expect(transport.requested, [baseUri]);
  });

  test(
    'fetch rejects redirects without location and excessive chains',
    () async {
      final missing = _SequenceTransport([_response(statusCode: 302)]);
      await expectLater(
        _configuredClient(baseUri, transport: missing.call).get(baseUri),
        throwsA(isA<ResearchHttpException>()),
      );

      final repeated = _SequenceTransport([
        _response(statusCode: 302, location: '/again'),
        _response(statusCode: 302, location: '/again'),
      ]);
      await expectLater(
        _configuredClient(
          baseUri,
          transport: repeated.call,
          maxRedirects: 1,
        ).get(baseUri),
        throwsA(isA<ResearchHttpException>()),
      );
      expect(repeated.requested, hasLength(2));
    },
  );

  test('body streaming is bounded by timeout and size', () async {
    final slow = _SequenceTransport([
      ResearchHttpTransportResponse(
        statusCode: 200,
        chunks: Stream<List<int>>.periodic(
          const Duration(milliseconds: 50),
          (_) => [1],
        ).take(2),
      ),
    ]);
    await expectLater(
      _configuredClient(
        baseUri,
        transport: slow.call,
        timeout: const Duration(milliseconds: 10),
      ).get(baseUri),
      throwsA(isA<TimeoutException>()),
    );

    final large = _SequenceTransport([
      _response(
        statusCode: 200,
        chunks: const [
          [1, 2],
          [3, 4],
        ],
      ),
    ]);
    await expectLater(
      _configuredClient(
        baseUri,
        transport: large.call,
        maxBytes: 3,
      ).get(baseUri),
      throwsA(isA<ResearchHttpException>()),
    );
  });
}

ResearchHttpClient _configuredClient(
  Uri uri, {
  required ResearchHttpTransport transport,
  int maxBytes = 256 * 1024,
  int maxRedirects = 3,
  Duration timeout = const Duration(seconds: 8),
}) {
  return ResearchHttpClient(
    allowedHosts: {uri.host},
    allowedOrigins: {uri.origin},
    maxBytes: maxBytes,
    maxRedirects: maxRedirects,
    timeout: timeout,
    transport: transport,
  );
}

ResearchHttpTransportResponse _response({
  required int statusCode,
  String? location,
  List<List<int>> chunks = const [],
}) {
  return ResearchHttpTransportResponse(
    statusCode: statusCode,
    location: location,
    chunks: Stream.fromIterable(chunks),
  );
}

class _SequenceTransport {
  _SequenceTransport(this.responses);

  final List<ResearchHttpTransportResponse> responses;
  final List<Uri> requested = [];

  Future<ResearchHttpTransportResponse> call(Uri uri, Duration timeout) async {
    requested.add(uri);
    return responses.removeAt(0);
  }
}
