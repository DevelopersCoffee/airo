import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:platform_playlist_export/platform_playlist_export.dart';
import 'package:platform_player/platform_player.dart';

/// Short-lived LAN-only HTTP server that lets a phone download an Aika Stream
/// backup JSON by scanning a QR code on the TV.
class TvLanBackupExportServer {
  TvLanBackupExportServer({
    required this.document,
    Future<List<PhoneMediaLanInterface>> Function()? interfaceLister,
    this.bindAddress,
    String? token,
    this.idleTimeout = const Duration(minutes: 5),
  }) : _interfaceLister = interfaceLister ?? _systemInterfaces,
       _token = token ?? _generateToken();

  static const int _maxRejectedRequests = 20;

  final AiroBackupDocument document;
  final Future<List<PhoneMediaLanInterface>> Function() _interfaceLister;
  final InternetAddress? bindAddress;
  final String _token;
  final Duration idleTimeout;

  HttpServer? _server;
  Timer? _idleTimer;
  int _rejectedRequests = 0;
  late final List<int> _payload = utf8.encode(document.contents);

  bool get isRunning => _server != null;

  /// Starts the server and returns the landing-page URL to encode as a QR code.
  Future<Uri> start() async {
    if (_payload.length > kAiroBackupMaximumBytes) {
      throw StateError('Backup is too large for a LAN transfer.');
    }
    final address =
        bindAddress ??
        PhoneMediaFileServer.selectLanAddress(await _interfaceLister());
    if (address == null) {
      throw StateError(
        'No private LAN address available; refusing to serve the backup.',
      );
    }
    final server = await HttpServer.bind(address, 0);
    _server = server;
    final url = Uri(
      scheme: 'http',
      host: address.address,
      port: server.port,
      path: '/backup/export/$_token',
    );
    server.listen(_handleRequest, onError: (_) {}, cancelOnError: false);
    _idleTimer = Timer(idleTimeout, () {
      unawaited(stop());
    });
    return url;
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    _idleTimer?.cancel();
    _idleTimer = null;
    if (server != null) await server.close(force: true);
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final response = request.response;
    try {
      final token = _tokenFromPath(request.uri.path);
      if (token == null || !_constantTimeEquals(token, _token)) {
        await _reject(response, HttpStatus.notFound);
        return;
      }

      if (request.uri.path.endsWith('/file')) {
        if (request.method != 'GET') {
          await _reject(response, HttpStatus.methodNotAllowed);
          return;
        }
        await _handleDownload(response);
        return;
      }

      if (request.method != 'GET') {
        await _reject(response, HttpStatus.methodNotAllowed);
        return;
      }
      await _handleLanding(response);
    } catch (_) {
      await _reject(response, HttpStatus.internalServerError);
    }
  }

  Future<void> _handleLanding(HttpResponse response) async {
    response.statusCode = HttpStatus.ok;
    response.headers.contentType = ContentType.html;
    response.write(_landingHtml(_token));
    await response.close();
  }

  Future<void> _handleDownload(HttpResponse response) async {
    response.statusCode = HttpStatus.ok;
    response.headers.contentType = ContentType('application', 'json');
    response.headers.set(
      'Content-Disposition',
      'attachment; filename="${document.fileName}"',
    );
    response.headers.contentLength = _payload.length;
    response.add(_payload);
    await response.close();
  }

  Future<void> _reject(HttpResponse response, int statusCode) async {
    _rejectedRequests++;
    try {
      response.statusCode = statusCode;
      await response.close();
    } catch (_) {}
    if (_rejectedRequests >= _maxRejectedRequests) {
      unawaited(stop());
    }
  }

  String? _tokenFromPath(String path) {
    const prefix = '/backup/export/';
    if (!path.startsWith(prefix)) return null;
    final remainder = path.substring(prefix.length);
    if (remainder.isEmpty) return null;
    if (remainder.endsWith('/file')) {
      final token = remainder.substring(0, remainder.length - '/file'.length);
      return token.isEmpty ? null : token;
    }
    return remainder;
  }

  static Future<List<PhoneMediaLanInterface>> _systemInterfaces() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
      includeLinkLocal: false,
    );
    return [
      for (final interface in interfaces)
        (name: interface.name, addresses: interface.addresses),
    ];
  }

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var mismatch = 0;
    for (var i = 0; i < a.length; i++) {
      mismatch |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return mismatch == 0;
  }

  static String _generateToken() {
    final random = Random.secure();
    const alphabet =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'
        '0123456789';
    return List.generate(
      32,
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();
  }
}

String _landingHtml(String token) {
  return '''
<!doctype html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Download Aika Stream backup</title>
<style>
body{font-family:sans-serif;max-width:480px;margin:48px auto;padding:0 20px;color:#1a1a1a}
h1{font-size:20px}
a,button{display:block;width:100%;box-sizing:border-box;padding:14px;font-size:16px;background:#0a84ff;color:#fff;border:none;border-radius:8px;text-align:center;text-decoration:none;margin-top:16px}
</style>
</head>
<body>
<h1>Download your Aika Stream backup</h1>
<p>Save this file somewhere safe, then import it on another device.</p>
<a href="/backup/export/$token/file">Download backup</a>
</body>
</html>
''';
}
