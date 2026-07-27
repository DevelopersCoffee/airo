import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:platform_player/platform_player.dart';

/// Short-lived LAN-only HTTP server that lets a phone hand a playlist URL to
/// the TV by scanning a QR code (issues/04-recovery-states.md's empty-state
/// "phone QR" onboarding). The phone never needs the Airo app installed --
/// it gets a plain HTML form.
///
/// Mirrors [PhoneMediaFileServer]'s already-reviewed safety pattern (private-
/// LAN-only binding, constant-time token comparison, redacted logging) for
/// the opposite direction: the TV serves the form and receives the URL,
/// rather than serving media.
class TvPlaylistPairingServer {
  TvPlaylistPairingServer({
    Future<List<PhoneMediaLanInterface>> Function()? interfaceLister,
    this.bindAddress,
    String? token,
    this.idleTimeout = const Duration(minutes: 5),
    this.stopGracePeriod = const Duration(seconds: 2),
  }) : _interfaceLister = interfaceLister ?? _systemInterfaces,
       _token = token ?? _generateToken();

  static const int _maxRejectedRequests = 20;

  final Future<List<PhoneMediaLanInterface>> Function() _interfaceLister;
  final InternetAddress? bindAddress;
  final String _token;
  final Duration idleTimeout;
  final Duration stopGracePeriod;

  HttpServer? _server;
  Timer? _idleTimer;
  bool _consumed = false;
  int _rejectedRequests = 0;
  final _resultCompleter = Completer<String?>();

  bool get isRunning => _server != null;

  /// Resolves with the submitted playlist URL, or `null` if the session
  /// expired, was cancelled, or was stopped after too many bad requests --
  /// never with a URL that wasn't validated by [_handlePost].
  Future<String?> get result => _resultCompleter.future;

  /// Starts the server and returns the pairing URL to encode as a QR code.
  /// Throws [StateError] if no private LAN address is available -- callers
  /// must not fall back to a public/carrier interface.
  Future<Uri> start() async {
    final address =
        bindAddress ??
        PhoneMediaFileServer.selectLanAddress(await _interfaceLister());
    if (address == null) {
      throw StateError(
        'No private LAN address available; refusing to serve the pairing form.',
      );
    }
    final server = await HttpServer.bind(address, 0);
    _server = server;
    final url = Uri(
      scheme: 'http',
      host: address.address,
      port: server.port,
      path: '/pair/$_token',
    );
    server.listen(_handleRequest, onError: (_) {}, cancelOnError: false);
    _idleTimer = Timer(idleTimeout, () {
      unawaited(stop());
    });
    return url;
  }

  /// Cancels the session without a result. Safe to call whether or not the
  /// server is running, and safe to call more than once.
  Future<void> cancel() async {
    await stop();
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    _idleTimer?.cancel();
    _idleTimer = null;
    if (server != null) await server.close(force: true);
    if (!_resultCompleter.isCompleted) _resultCompleter.complete(null);
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final response = request.response;
    try {
      final token = _tokenFromPath(request.uri.path);
      if (token == null || !_constantTimeEquals(token, _token)) {
        await _reject(response, HttpStatus.notFound);
        return;
      }
      if (_consumed) {
        // Single-use: a second request against an already-consumed token
        // (a race, a reload, or an attacker's guess after the fact) gets
        // the same "gone" treatment regardless of method.
        await _reject(response, HttpStatus.gone);
        return;
      }

      switch (request.method) {
        case 'GET':
          await _handleGet(response);
        case 'POST':
          await _handlePost(request, response);
        default:
          await _reject(response, HttpStatus.methodNotAllowed);
      }
    } catch (_) {
      await _reject(response, HttpStatus.internalServerError);
    }
  }

  Future<void> _handleGet(HttpResponse response) async {
    response.statusCode = HttpStatus.ok;
    response.headers.contentType = ContentType.html;
    response.write(_formHtml);
    await response.close();
  }

  Future<void> _handlePost(HttpRequest request, HttpResponse response) async {
    final body = await _readUrlEncodedForm(request);
    final url = body['url']?.trim();
    if (url == null || url.isEmpty) {
      response.statusCode = HttpStatus.badRequest;
      response.headers.contentType = ContentType.html;
      response.write(_formHtml);
      await response.close();
      return;
    }

    // Set the moment a valid submission is accepted -- synchronously, no
    // await before this point in the handler -- so a second concurrent
    // request against the same token can never also complete the result.
    _consumed = true;
    _idleTimer?.cancel();
    if (!_resultCompleter.isCompleted) _resultCompleter.complete(url);

    response.statusCode = HttpStatus.ok;
    response.headers.contentType = ContentType.html;
    response.write(_successHtml);
    await response.close();

    unawaited(
      Future<void>.delayed(stopGracePeriod, () {
        if (isRunning) unawaited(stop());
      }),
    );
  }

  Future<void> _reject(HttpResponse response, int statusCode) async {
    _rejectedRequests++;
    try {
      response.statusCode = statusCode;
      await response.close();
    } catch (_) {
      // Socket already gone; nothing to clean up.
    }
    if (_rejectedRequests >= _maxRejectedRequests) {
      unawaited(stop());
    }
  }

  static Future<Map<String, String>> _readUrlEncodedForm(
    HttpRequest request,
  ) async {
    final raw = await utf8.decoder.bind(request).join();
    return Uri(query: raw).queryParameters;
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

  String? _tokenFromPath(String path) {
    const prefix = '/pair/';
    if (!path.startsWith(prefix)) return null;
    final token = path.substring(prefix.length);
    return token.isEmpty ? null : token;
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

  @override
  String toString() {
    return 'TvPlaylistPairingServer('
        'running: $isRunning, '
        'consumed: $_consumed, '
        'url: redacted'
        ')';
  }
}

const _formHtml = '''
<!doctype html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Add playlist to Airo TV</title>
<style>
body{font-family:sans-serif;max-width:480px;margin:48px auto;padding:0 20px;color:#1a1a1a}
h1{font-size:20px}
input{width:100%;box-sizing:border-box;padding:12px;font-size:16px;border:1px solid #ccc;border-radius:8px;margin:12px 0}
button{width:100%;padding:14px;font-size:16px;background:#0a84ff;color:#fff;border:none;border-radius:8px}
</style>
</head>
<body>
<h1>Add a playlist to your TV</h1>
<form method="POST">
<input name="url" type="url" placeholder="https://example.com/playlist.m3u" required autofocus>
<button type="submit">Send to TV</button>
</form>
</body>
</html>
''';

const _successHtml = '''
<!doctype html>
<html>
<head><meta charset="utf-8"><title>Sent</title></head>
<body style="font-family:sans-serif;max-width:480px;margin:48px auto;padding:0 20px">
<h1>Sent to your TV</h1>
<p>Check your TV screen to finish adding the playlist.</p>
</body>
</html>
''';
