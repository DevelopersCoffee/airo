import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:platform_playlist_export/platform_playlist_export.dart';
import 'package:platform_player/platform_player.dart';

/// Short-lived LAN-only HTTP server that lets a phone upload an Aika Stream
/// backup JSON to the TV by scanning a QR code.
class TvLanBackupImportServer {
  TvLanBackupImportServer({
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
  final _resultCompleter = Completer<AiroBackupDocument?>();

  bool get isRunning => _server != null;

  Future<AiroBackupDocument?> get result => _resultCompleter.future;

  Future<Uri> start() async {
    final address =
        bindAddress ??
        PhoneMediaFileServer.selectLanAddress(await _interfaceLister());
    if (address == null) {
      throw StateError(
        'No private LAN address available; refusing to accept a backup upload.',
      );
    }
    final server = await HttpServer.bind(address, 0);
    _server = server;
    final url = Uri(
      scheme: 'http',
      host: address.address,
      port: server.port,
      path: '/backup/import/$_token',
    );
    server.listen(_handleRequest, onError: (_) {}, cancelOnError: false);
    _idleTimer = Timer(idleTimeout, () {
      unawaited(stop());
    });
    return url;
  }

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
    final raw = await utf8.decoder.bind(request).join();
    if (raw.length > kAiroBackupMaximumBytes) {
      response.statusCode = HttpStatus.requestEntityTooLarge;
      response.headers.contentType = ContentType.html;
      response.write(_formHtml);
      await response.close();
      return;
    }

    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      response.statusCode = HttpStatus.badRequest;
      response.headers.contentType = ContentType.html;
      response.write(_formHtml);
      await response.close();
      return;
    }

    _consumed = true;
    _idleTimer?.cancel();
    if (!_resultCompleter.isCompleted) {
      _resultCompleter.complete(
        AiroBackupDocument(
          fileName: 'airo_tv_backup_upload.json',
          mediaType: 'application/json',
          contents: trimmed,
        ),
      );
    }

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
    } catch (_) {}
    if (_rejectedRequests >= _maxRejectedRequests) {
      unawaited(stop());
    }
  }

  String? _tokenFromPath(String path) {
    const prefix = '/backup/import/';
    if (!path.startsWith(prefix)) return null;
    final token = path.substring(prefix.length);
    return token.isEmpty ? null : token;
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

const _formHtml = '''
<!doctype html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Send backup to Aika Stream</title>
<style>
body{font-family:sans-serif;max-width:480px;margin:48px auto;padding:0 20px;color:#1a1a1a}
h1{font-size:20px}
input{width:100%;box-sizing:border-box;padding:12px;font-size:16px;border:1px solid #ccc;border-radius:8px;margin:12px 0}
button{width:100%;padding:14px;font-size:16px;background:#0a84ff;color:#fff;border:none;border-radius:8px}
</style>
</head>
<body>
<h1>Send a backup to your TV</h1>
<p>Choose the Aika Stream backup JSON you saved on your phone.</p>
<input id="file" type="file" accept=".json,application/json">
<button type="button" onclick="upload()">Send to TV</button>
<p id="status"></p>
<script>
async function upload() {
  const input = document.getElementById('file');
  const status = document.getElementById('status');
  const file = input.files && input.files[0];
  if (!file) {
    status.textContent = 'Choose a backup file first.';
    return;
  }
  status.textContent = 'Sending…';
  try {
    const body = await file.text();
    const response = await fetch(window.location.pathname, {
      method: 'POST',
      headers: {'Content-Type': 'application/json; charset=utf-8'},
      body
    });
    if (!response.ok) {
      status.textContent = 'Upload failed. Try again.';
      return;
    }
    status.textContent = 'Sent to your TV. Check the TV screen.';
  } catch (_) {
    status.textContent = 'Upload failed. Try again.';
  }
}
</script>
</body>
</html>
''';

const _successHtml = '''
<!doctype html>
<html>
<head><meta charset="utf-8"><title>Sent</title></head>
<body style="font-family:sans-serif;max-width:480px;margin:48px auto;padding:0 20px">
<h1>Sent to your TV</h1>
<p>Check your TV screen to finish importing the backup.</p>
</body>
</html>
''';
