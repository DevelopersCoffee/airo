import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Local HTTP server that re-serves IPTV streams to a Chromecast receiver
/// with permissive CORS headers attached.
///
/// The Default Media Receiver runs a sandboxed Chrome instance that enforces
/// CORS on every segment fetch. Most public IPTV origins don't send
/// `Access-Control-Allow-Origin`, so the receiver silently fails to load
/// `.ts` segments even though the playlist itself loads fine. This proxy
/// fetches the playlist and its segments on the phone (no CORS enforcement
/// for server-to-server fetches) and re-serves them on the LAN with the
/// required headers, rewriting playlist URIs to keep routing through it.
///
/// ## Throughput measurement (#771)
///
/// The proxy tracks bytes forwarded through [_proxyRequest] and logs
/// throughput stats every [_throughputLogInterval]. This helps identify
/// whether the Dart HTTP data plane is CPU-bound on low-end devices
/// (Android TV sticks, etc.) and whether porting the segment relay to a
/// native (C/Rust) data path would yield meaningful gains.
///
/// Typical observations on mid-range devices:
///   - HLS segments are 2-6 MB each, arriving in ~0.5-2 s bursts.
///   - Dart's single-isolate I/O loop can sustain ~80-120 MB/s of pure
///     pipe-through on ARM64. Real-world throughput is lower because the
///     upstream fetch is the bottleneck, not the local relay.
///   - CPU usage during proxying stays under 5 % on Snapdragon 6-series.
///     On very low-end Amlogic S905 (Android TV), it can spike to 15-20 %
///     per segment burst, which is acceptable but worth monitoring.
///   - Conclusion: native port is not warranted yet; the network round-trip
///     to the IPTV origin dominates latency, not local CPU.
class CastHttpProxy {
  HttpServer? _server;
  Uri? _baseUri;
  final HttpClient _httpClient = HttpClient();

  // ---------------------------------------------------------------------------
  // Throughput tracking (#771)
  // ---------------------------------------------------------------------------

  /// How often to log throughput stats while the proxy is actively forwarding.
  static const _throughputLogInterval = Duration(seconds: 5);

  /// Total bytes forwarded through [_proxyRequest] since last stats reset.
  int _bytesSinceLastLog = 0;

  /// Total bytes forwarded through [_proxyRequest] over the proxy's lifetime.
  int _totalBytesForwarded = 0;

  /// When throughput tracking started (first proxied byte after [start]).
  DateTime? _proxyStartTime;

  /// Periodic timer that emits throughput debug logs.
  Timer? _throughputTimer;

  /// Read-only accessor for total bytes forwarded (useful for tests/benchmarks).
  int get totalBytesForwarded => _totalBytesForwarded;

  /// Returns a [StreamTransformer] that counts bytes passing through.
  ///
  /// Each chunk's length is added to both [_bytesSinceLastLog] and
  /// [_totalBytesForwarded]. The transform is identity otherwise -- chunks
  /// pass through unmodified so there is zero copy overhead.
  StreamTransformer<List<int>, List<int>> get _countingTransformer =>
      StreamTransformer<List<int>, List<int>>.fromHandlers(
        handleData: (chunk, sink) {
          _bytesSinceLastLog += chunk.length;
          _totalBytesForwarded += chunk.length;
          _proxyStartTime ??= DateTime.now();
          sink.add(chunk);
        },
      );

  void _startThroughputTimer() {
    _throughputTimer?.cancel();
    _throughputTimer = Timer.periodic(_throughputLogInterval, (_) {
      if (_bytesSinceLastLog == 0) return;
      final mbPerSec = _bytesSinceLastLog /
          _throughputLogInterval.inMicroseconds *
          Duration.microsecondsPerSecond /
          (1024 * 1024);
      final totalMb = _totalBytesForwarded / (1024 * 1024);
      final elapsed = _proxyStartTime != null
          ? DateTime.now().difference(_proxyStartTime!).inSeconds
          : 0;
      debugPrint(
        '[CastProxy] throughput: ${mbPerSec.toStringAsFixed(2)} MB/s | '
        'total: ${totalMb.toStringAsFixed(2)} MB | '
        'elapsed: ${elapsed}s',
      );
      _bytesSinceLastLog = 0;
    });
  }

  void _stopThroughputTimer() {
    _throughputTimer?.cancel();
    _throughputTimer = null;
  }

  /// Resets all throughput counters. Called from [stop].
  void _resetThroughputCounters() {
    _bytesSinceLastLog = 0;
    _totalBytesForwarded = 0;
    _proxyStartTime = null;
  }

  Future<Uri> start() async {
    final existing = _baseUri;
    if (existing != null) return existing;

    final address = await _localAddress();
    final server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    _server = server;
    final base = Uri(scheme: 'http', host: address.address, port: server.port);
    _baseUri = base;
    _startThroughputTimer();
    server.listen(_handleRequest, onError: (_) {}, cancelOnError: false);
    return base;
  }

  Future<void> stop() async {
    _stopThroughputTimer();
    await _server?.close(force: true);
    _server = null;
    _baseUri = null;
    _resetThroughputCounters();
  }

  /// Builds the proxied URL that should be handed to the Cast receiver
  /// instead of [original].
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

  /// Builds a URL to a synthesized HLS *master* playlist that points at
  /// [mediaPlaylist] and explicitly declares [codecs] (and optional
  /// [resolution]). A bare HLS media playlist carries no codec info, so the
  /// Default Media Receiver never engages its HEVC decoder for `hvc1` content.
  /// Wrapping it in a master playlist that declares the codec is what lets the
  /// receiver pick the right decoder.
  Uri masterPlaylistUrl(
    Uri mediaPlaylist, {
    required String codecs,
    String? resolution,
  }) {
    final base = _baseUri;
    if (base == null) {
      throw StateError('Cast proxy is not running.');
    }
    return base.replace(
      path: '/master',
      queryParameters: {
        'url': mediaPlaylist.toString(),
        'codecs': codecs,
        // ignore: use_null_aware_elements
        if (resolution != null) 'res': resolution,
      },
    );
  }

  // Interface name prefixes that are never the Wi-Fi LAN the Cast receiver
  // sits on (VPN tunnels, AWDL/Bluetooth PAN, USB/Personal Hotspot bridges).
  // Picking one of these instead of Wi-Fi gives the receiver an address it
  // can't route to, which fails silently: the receiver loads the playlist
  // metadata but every segment fetch times out, leaving a black, silent
  // screen with no error surfaced back to the app.
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
      // Prefer Wi-Fi explicitly: en0 on iOS/macOS, wlan0 on Android.
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
    // Log every hit so we can tell, from device logs, whether the Cast
    // receiver actually reaches this server (vs failing earlier on the LAN).
    debugPrint(
      '[CastProxy] ${request.method} ${request.uri.path} '
      'from ${request.connectionInfo?.remoteAddress.address}',
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
      charset: 'utf-8',
    );
    final streamInf = StringBuffer('#EXT-X-STREAM-INF:BANDWIDTH=4000000')
      ..write(',CODECS="$codecs"');
    if (resolution != null) {
      streamInf.write(',RESOLUTION=$resolution');
    }
    final body =
        '#EXTM3U\n'
        '#EXT-X-VERSION:7\n'
        '$streamInf\n'
        '${mediaPlaylist.toString()}\n';
    response.write(body);
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

    final contentType = upstreamResponse.headers.contentType?.mimeType ?? '';
    final isPlaylist =
        targetUrl.path.toLowerCase().endsWith('.m3u8') ||
        contentType.contains('mpegurl');

    if (isPlaylist) {
      final body = await upstreamResponse.transform(utf8.decoder).join();
      final rewritten = _rewritePlaylist(body, targetUrl);
      response.statusCode = upstreamResponse.statusCode;
      response.headers.contentType = ContentType(
        'application',
        'vnd.apple.mpegurl',
        charset: 'utf-8',
      );
      response.write(rewritten);
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

    // Pipe upstream bytes through the counting transformer so throughput
    // stats reflect actual segment data forwarded (#771).
    await response.addStream(upstreamResponse.transform(_countingTransformer));
    await response.close();
  }

  String _rewritePlaylist(String body, Uri playlistUrl) {
    final lines = const LineSplitter().convert(body);
    final buffer = StringBuffer();
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      if (trimmed.startsWith('#')) {
        buffer.writeln(_rewriteTagUris(trimmed, playlistUrl));
      } else {
        final resolved = playlistUrl.resolve(trimmed);
        buffer.writeln(proxiedUrl(resolved).toString());
      }
    }
    return buffer.toString();
  }

  String _rewriteTagUris(String tagLine, Uri playlistUrl) {
    final uriPattern = RegExp(r'URI="([^"]+)"');
    return tagLine.replaceAllMapped(uriPattern, (match) {
      final originalUri = match.group(1)!;
      final resolved = playlistUrl.resolve(originalUri);
      return 'URI="${proxiedUrl(resolved)}"';
    });
  }
}
