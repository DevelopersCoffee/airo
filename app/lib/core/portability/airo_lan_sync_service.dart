import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

/// A short-lived, token-protected LAN endpoint for an already encrypted Airo
/// backup envelope. The server never sees or handles plaintext backup data.
class AiroLanShare {
  AiroLanShare(this.uri, this._server, this._expiry);

  final Uri uri;
  final HttpServer _server;
  final Timer _expiry;

  Future<void> close() async {
    _expiry.cancel();
    await _server.close(force: true);
  }
}

class AiroLanSyncService {
  static const maxPayloadBytes = 10 * 1024 * 1024;
  static const defaultConnectionTimeout = Duration(seconds: 8);
  static const defaultTransferTimeout = Duration(seconds: 30);

  const AiroLanSyncService({
    this.connectionTimeout = defaultConnectionTimeout,
    this.transferTimeout = defaultTransferTimeout,
  });

  final Duration connectionTimeout;
  final Duration transferTimeout;

  Future<AiroLanShare> createShare(
    String encryptedBackup, {
    Duration ttl = const Duration(minutes: 10),
    String? advertisedHost,
  }) async {
    final payload = utf8.encode(encryptedBackup);
    if (payload.length > maxPayloadBytes) {
      throw const FormatException('Backup is too large for a LAN transfer');
    }

    final token = _newToken();
    final route = '/airo-sync/$token';
    final server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    final host = advertisedHost ?? await _findLanAddress(server);
    late final Timer expiry;
    expiry = Timer(ttl, () => server.close(force: true));

    server.listen((request) async {
      if (request.method != 'GET' || request.uri.path != route) {
        request.response
          ..statusCode = HttpStatus.notFound
          ..close();
        return;
      }
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType('text', 'plain', charset: 'utf-8')
        ..headers.contentLength = payload.length
        ..add(payload);
      await request.response.close();
    });

    return AiroLanShare(
      Uri(scheme: 'http', host: host, port: server.port, path: route),
      server,
      expiry,
    );
  }

  Future<String> fetchShare(Uri uri) async {
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      throw const FormatException('LAN share must use HTTP or HTTPS');
    }
    final client = HttpClient()..connectionTimeout = connectionTimeout;
    try {
      final request = await client.getUrl(uri).timeout(transferTimeout);
      final response = await request.close().timeout(transferTimeout);
      if (response.statusCode != HttpStatus.ok) {
        throw FormatException('LAN share returned HTTP ${response.statusCode}');
      }
      if (response.contentLength > maxPayloadBytes) {
        throw const FormatException('LAN share is too large');
      }
      final bytes = await response.fold<List<int>>(
        <int>[],
        (buffer, chunk) => buffer..addAll(chunk),
      ).timeout(transferTimeout);
      if (bytes.length > maxPayloadBytes) {
        throw const FormatException('LAN share is too large');
      }
      return utf8.decode(bytes);
    } finally {
      client.close(force: true);
    }
  }

  String _newToken() {
    final random = Random.secure();
    return base64UrlEncode(
      List<int>.generate(24, (_) => random.nextInt(256), growable: false),
    ).replaceAll('=', '');
  }

  Future<String> _findLanAddress(HttpServer server) async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
        includeLinkLocal: false,
      );
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          if (!address.isLoopback) return address.address;
        }
      }
    } on Object {
      // Fall through to the bind address for restricted platforms.
    }
    return server.address.address;
  }
}
