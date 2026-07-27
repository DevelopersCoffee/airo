import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

final class IptvOrgRequest {
  const IptvOrgRequest({required this.uri, this.headers = const {}});

  final Uri uri;
  final Map<String, String> headers;
}

final class IptvOrgResponse {
  const IptvOrgResponse({
    required this.statusCode,
    required this.body,
    this.headers = const {},
  });

  final int statusCode;
  final Uint8List body;
  final Map<String, String> headers;

  String? header(String name) => headers[name.toLowerCase()];
}

abstract interface class IptvOrgTransport {
  Future<IptvOrgResponse> get(IptvOrgRequest request);
}

/// `dart:io` transport for CLI, worker, and native application consumers.
final class IoIptvOrgTransport implements IptvOrgTransport {
  IoIptvOrgTransport({
    HttpClient? client,
    this.timeout = const Duration(seconds: 30),
  }) : _client = client ?? HttpClient();

  final HttpClient _client;
  final Duration timeout;

  @override
  Future<IptvOrgResponse> get(IptvOrgRequest request) async {
    final ioRequest = await _client.getUrl(request.uri).timeout(timeout);
    request.headers.forEach(ioRequest.headers.set);
    final ioResponse = await ioRequest.close().timeout(timeout);
    final builder = BytesBuilder(copy: false);
    await for (final bytes in ioResponse.timeout(timeout)) {
      builder.add(bytes);
    }
    final headers = <String, String>{};
    ioResponse.headers.forEach((name, values) {
      headers[name.toLowerCase()] = values.join(',');
    });
    return IptvOrgResponse(
      statusCode: ioResponse.statusCode,
      body: builder.takeBytes(),
      headers: Map.unmodifiable(headers),
    );
  }
}

final class IptvOrgHttpException implements IOException {
  const IptvOrgHttpException(this.statusCode, this.endpoint);

  final int statusCode;
  final String endpoint;

  @override
  String toString() =>
      'IptvOrgHttpException: HTTP $statusCode while fetching $endpoint';
}
