import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

typedef FakeResponseBuilder = Response<dynamic> Function(
  RequestOptions options,
);

/// Matches outgoing requests by [RequestOptions.path] (the path argument
/// passed to `dio.get(...)`, not the full URL) against a handler map, and
/// returns the handler's [Response] JSON-encoded. Shared across the
/// Xtream/Stalker/Jellyfin adapter tests — each speaks JSON over HTTP with
/// a small, fixed set of endpoints, so one fake per test file just needs a
/// different handler map.
class FakeHttpClientAdapter implements HttpClientAdapter {
  FakeHttpClientAdapter(this._handlers);

  final Map<String, FakeResponseBuilder> _handlers;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final handler = _handlers[options.path];
    if (handler == null) {
      throw DioException(
        requestOptions: options,
        error: 'No fake handler registered for ${options.path}',
      );
    }
    final response = handler(options);
    final bodyBytes = utf8.encode(jsonEncode(response.data));
    return ResponseBody.fromBytes(
      bodyBytes,
      response.statusCode ?? 200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
