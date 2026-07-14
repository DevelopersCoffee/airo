import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Local HTTP server that re-serves media to a Cast receiver with permissive
/// CORS headers.
///
/// This is intentionally opt-in. The receiver should load public origin URLs
/// directly when possible. The proxy is used for compatibility cases where the
/// receiver needs a local rewritten playlist, such as synthesized HEVC master
/// playlists or live IPTV manifests with relative child playlists.
class CastHttpProxy {
  HttpServer? _server;
  Uri? _baseUri;
  final HttpClient _httpClient = HttpClient();

  Future<Uri> start() async {
    final existing = _baseUri;
    if (existing != null) return existing;

    final address = await _localAddress();
    final server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    _server = server;
    final base = Uri(scheme: 'http', host: address.address, port: server.port);
    _baseUri = base;
    debugPrint('[CastProxy] listening on ${_uriSummary(base)}');
    server.listen(_handleRequest, onError: (_) {}, cancelOnError: false);
    return base;
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _baseUri = null;
  }

  Uri proxiedUrl(Uri original) {
    final base = _baseUri;
    if (base == null) {
      throw StateError('Cast proxy is not running.');
    }
    return base.replace(
      path: '/proxy',
      queryParameters: {'url': original.toString()},
    );
  }

  Uri masterPlaylistUrl(
    Uri mediaPlaylist, {
    required String codecs,
    String? resolution,
  }) {
    final base = _baseUri;
    if (base == null) {
      throw StateError('Cast proxy is not running.');
    }
    final queryParameters = {'url': mediaPlaylist.toString(), 'codecs': codecs};
    if (resolution != null) {
      queryParameters['res'] = resolution;
    }
    return base.replace(path: '/master', queryParameters: queryParameters);
  }

  static const _nonLanInterfacePrefixes = [
    'utun',
    'ipsec',
    'ppp',
    'llw',
    'awdl',
    'bridge',
  ];

  Future<InternetAddress> _localAddress() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
      includeLinkLocal: false,
    );

    InternetAddress? fallback;
    for (final interface in interfaces) {
      final name = interface.name.toLowerCase();
      if (name == 'en0' || name.startsWith('wlan')) {
        for (final addr in interface.addresses) {
          if (!addr.isLoopback) return addr;
        }
      }
      if (_nonLanInterfacePrefixes.any(name.startsWith)) continue;
      for (final addr in interface.addresses) {
        if (!addr.isLoopback) {
          fallback ??= addr;
        }
      }
    }
    return fallback ?? InternetAddress.loopbackIPv4;
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final response = request.response;
    debugPrint(
      '[CastProxy] ${request.method} ${request.uri.path} '
      'from ${request.connectionInfo?.remoteAddress.address} '
      'target=${_uriSummary(Uri.tryParse(request.uri.queryParameters['url'] ?? ''))}',
    );
    response.headers
      ..add('Access-Control-Allow-Origin', '*')
      ..add('Access-Control-Allow-Headers', '*')
      ..add('Access-Control-Allow-Methods', '*');

    if (request.method == 'OPTIONS') {
      await response.close();
      return;
    }

    final targetParam = request.uri.queryParameters['url'];
    if (targetParam == null) {
      response.statusCode = HttpStatus.notFound;
      await response.close();
      return;
    }

    final targetUrl = Uri.tryParse(targetParam);
    if (targetUrl == null) {
      response.statusCode = HttpStatus.badRequest;
      await response.close();
      return;
    }

    try {
      if (request.uri.path == '/master') {
        await _serveMasterPlaylist(request, targetUrl);
      } else if (request.uri.path == '/proxy') {
        await _proxyRequest(request, targetUrl);
      } else {
        response.statusCode = HttpStatus.notFound;
        await response.close();
      }
    } catch (error) {
      debugPrint('[CastProxy] error serving ${request.uri.path}: $error');
      response.statusCode = HttpStatus.badGateway;
      await response.close();
    }
  }

  Future<void> _serveMasterPlaylist(
    HttpRequest request,
    Uri mediaPlaylist,
  ) async {
    final codecs = request.uri.queryParameters['codecs'] ?? '';
    final resolution = request.uri.queryParameters['res'];
    final response = request.response;
    response.statusCode = HttpStatus.ok;
    response.headers.contentType = ContentType(
      'application',
      'vnd.apple.mpegurl',
    );
    final streamInf = StringBuffer('#EXT-X-STREAM-INF:BANDWIDTH=4000000')
      ..write(',CODECS="$codecs"');
    if (resolution != null) {
      streamInf.write(',RESOLUTION=$resolution');
    }
    response.write(
      '#EXTM3U\n'
      '#EXT-X-VERSION:7\n'
      '$streamInf\n'
      '${mediaPlaylist.toString()}\n',
    );
    await response.close();
  }

  Future<void> _proxyRequest(HttpRequest request, Uri targetUrl) async {
    final upstreamRequest = await _httpClient.getUrl(targetUrl);
    final range = request.headers.value(HttpHeaders.rangeHeader);
    if (range != null) {
      upstreamRequest.headers.set(HttpHeaders.rangeHeader, range);
    }
    final upstreamResponse = await upstreamRequest.close();
    final response = request.response;
    debugPrint(
      '[CastProxy] upstream ${upstreamResponse.statusCode} '
      '${_uriSummary(targetUrl)} '
      'type=${upstreamResponse.headers.contentType?.mimeType ?? 'unknown'}',
    );

    final contentType = upstreamResponse.headers.contentType?.mimeType ?? '';
    final isPlaylist =
        targetUrl.path.toLowerCase().endsWith('.m3u8') ||
        contentType.contains('mpegurl');

    if (isPlaylist) {
      final body = await upstreamResponse.transform(utf8.decoder).join();
      response.statusCode = upstreamResponse.statusCode;
      response.headers.contentType = ContentType(
        'application',
        'vnd.apple.mpegurl',
      );
      response.write(_rewritePlaylist(body, targetUrl));
      await response.close();
      return;
    }

    response.statusCode = upstreamResponse.statusCode;
    final upstreamContentType = upstreamResponse.headers.contentType;
    if (upstreamContentType != null) {
      response.headers.contentType = upstreamContentType;
    }
    final contentLength = upstreamResponse.headers.value(
      HttpHeaders.contentLengthHeader,
    );
    if (contentLength != null) {
      response.headers.set(HttpHeaders.contentLengthHeader, contentLength);
    }
    final contentRange = upstreamResponse.headers.value(
      HttpHeaders.contentRangeHeader,
    );
    if (contentRange != null) {
      response.headers.set(HttpHeaders.contentRangeHeader, contentRange);
    }
    response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');

    await response.addStream(upstreamResponse);
    await response.close();
  }

  String _rewritePlaylist(String body, Uri playlistUrl) {
    final lines = const LineSplitter().convert(body);
    final buffer = StringBuffer();
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      if (_shouldDropTag(trimmed)) continue;
      if (trimmed.startsWith('#')) {
        buffer.writeln(_rewriteTagUris(trimmed, playlistUrl));
      } else {
        buffer.writeln(proxiedUrl(playlistUrl.resolve(trimmed)).toString());
      }
    }
    return buffer.toString();
  }

  String _rewriteTagUris(String tagLine, Uri playlistUrl) {
    final uriPattern = RegExp(r'URI="([^"]+)"');
    return tagLine.replaceAllMapped(uriPattern, (match) {
      final resolved = playlistUrl.resolve(match.group(1)!);
      return 'URI="${proxiedUrl(resolved)}"';
    });
  }

  bool _shouldDropTag(String line) {
    if (!line.startsWith('#EXT-X-MEDIA')) return false;
    return line.contains('TYPE=SUBTITLES') ||
        line.contains('TYPE=CLOSED-CAPTIONS');
  }

  String _uriSummary(Uri? uri) {
    if (uri == null) return 'none';
    final port = uri.hasPort ? ':${uri.port}' : '';
    return '${uri.scheme}://${uri.host}$port${uri.path}';
  }
}
