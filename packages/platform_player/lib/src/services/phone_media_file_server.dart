import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:core_media_routing/core_media_routing.dart';
import 'package:flutter/foundation.dart';

/// A network interface candidate for LAN binding: OS name plus its addresses.
typedef PhoneMediaLanInterface = ({
  String name,
  List<InternetAddress> addresses,
});

/// Short-lived LAN HTTP server that streams one phone-local media file to a
/// storage-limited receiver (CV-033).
///
/// The receiver never persists the file: it plays a tokenized LAN URL served
/// straight from the phone with HTTP Range support so seeking works. Range,
/// grant, expiry, and idle decisions are delegated to the existing
/// [AiroTemporaryMobileServerServingPolicy] contract from `core_media_routing`;
/// this class only owns the socket, the file stream, and session lifecycle.
class PhoneMediaFileServer implements AiroTemporaryMobileServerController {
  PhoneMediaFileServer({
    required AiroTemporaryMobileServerSnapshot snapshot,
    required this.filePath,
    required this.contentType,
    this._servingPolicy = const AiroTemporaryMobileServerServingPolicy(),
    this._bindAddress,
    Future<List<PhoneMediaLanInterface>> Function()? interfaceLister,
    String? sessionToken,
    DateTime Function()? now,
    this.onSessionEvent,
  }) : _initialSnapshot = snapshot,
       _interfaceLister = interfaceLister ?? _systemInterfaces,
       _sessionToken = sessionToken ?? _generateSessionToken(),
       _now = now ?? DateTime.now;

  final String filePath;
  final String contentType;
  final AiroTemporaryMobileServerSnapshot _initialSnapshot;
  final AiroTemporaryMobileServerServingPolicy _servingPolicy;
  final InternetAddress? _bindAddress;
  final Future<List<PhoneMediaLanInterface>> Function() _interfaceLister;
  final String _sessionToken;
  final DateTime Function() _now;

  /// Diagnostics hook (CV-001). Events carry stable ids only — never URLs,
  /// tokens, or file paths.
  final void Function(String event, Map<String, Object?> data)? onSessionEvent;

  HttpServer? _server;
  Uri? _mediaUrl;
  DateTime? _lastActivityAt;
  Timer? _lifecycleTimer;

  bool get isRunning => _server != null;

  /// True only for RFC1918 private ranges and loopback. Carrier-grade NAT
  /// (100.64/10), link-local, and public addresses are all rejected so the
  /// server can never bind or accept traffic outside the local network.
  static bool isPrivateLanAddress(InternetAddress address) {
    if (address.isLoopback) return true;
    if (address.type != InternetAddressType.IPv4) return false;
    final octets = address.rawAddress;
    if (octets[0] == 10) return true;
    if (octets[0] == 172 && octets[1] >= 16 && octets[1] <= 31) return true;
    if (octets[0] == 192 && octets[1] == 168) return true;
    return false;
  }

  /// Picks the bind address by allow-listing private LAN addresses: prefers
  /// the Wi-Fi interface (`en0`/`wlan*`), otherwise any interface with a
  /// private address. Returns null when no private address exists — callers
  /// must fail loudly instead of exposing a carrier or public interface.
  static InternetAddress? selectLanAddress(
    List<PhoneMediaLanInterface> interfaces,
  ) {
    InternetAddress? fallback;
    for (final interface in interfaces) {
      final name = interface.name.toLowerCase();
      for (final address in interface.addresses) {
        if (address.isLoopback || !isPrivateLanAddress(address)) continue;
        if (name == 'en0' || name.startsWith('wlan')) return address;
        fallback ??= address;
      }
    }
    return fallback;
  }

  /// Binds a random port on the LAN interface (or [_bindAddress] override) and
  /// returns the tokenized media URL to hand to the granted receiver.
  Future<Uri> start() async {
    final existing = _mediaUrl;
    if (existing != null) return existing;

    final address = _bindAddress ?? await _lanAddress();
    final server = await HttpServer.bind(address, 0);
    _server = server;
    _lastActivityAt = _now();
    final url = Uri(
      scheme: 'http',
      host: address.address,
      port: server.port,
      path: '/m/$_sessionToken/media',
    );
    _mediaUrl = url;
    server.listen(_handleRequest, onError: (_) {}, cancelOnError: false);
    _lifecycleTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => _enforceLifecycle(),
    );
    _emit('session_open', {'serverId': _initialSnapshot.serverId});
    return url;
  }

  Future<void> stopServer() async {
    final server = _server;
    if (server == null) return;
    _server = null;
    _mediaUrl = null;
    _lifecycleTimer?.cancel();
    _lifecycleTimer = null;
    await server.close(force: true);
    _emit('session_close', {'serverId': _initialSnapshot.serverId});
  }

  @override
  FutureOr<AiroTemporaryMobileServerSnapshot?> currentSnapshot() {
    if (!isRunning) return null;
    return _effectiveSnapshot();
  }

  @override
  FutureOr<AiroTemporaryMobileServerValidationResult> validate(
    AiroTemporaryMobileServerValidationContext context,
  ) {
    if (!isRunning) {
      return AiroTemporaryMobileServerValidationResult(
        serverId: 'none',
        codes: const [
          AiroTemporaryMobileServerValidationCode.serverUnavailable,
        ],
      );
    }
    return _servingPolicy.validationPolicy.validate(
      snapshot: _effectiveSnapshot(),
      context: context,
    );
  }

  @override
  FutureOr<AiroTemporaryMobileServerServingDecision> evaluateServing(
    AiroTemporaryMobileServerServingRequest request,
  ) {
    if (!isRunning) {
      return AiroTemporaryMobileServerServingDecision(
        serverId: 'none',
        requestId: request.requestId,
        status: AiroTemporaryMobileServerServingStatus.reject,
        validationCodes: const [
          AiroTemporaryMobileServerValidationCode.serverUnavailable,
        ],
        servingCodes: const [],
        responseHeaders: const {},
      );
    }
    return _servingPolicy.evaluate(
      snapshot: _effectiveSnapshot(),
      request: request,
    );
  }

  @override
  FutureOr<void> shutdown(String serverId) async {
    if (serverId != _initialSnapshot.serverId) return;
    await stopServer();
  }

  AiroTemporaryMobileServerSnapshot _effectiveSnapshot() {
    final base = _initialSnapshot;
    return AiroTemporaryMobileServerSnapshot(
      serverId: base.serverId,
      hostNodeId: base.hostNodeId,
      locationId: base.locationId,
      mediaId: base.mediaId,
      accessGrant: base.accessGrant,
      startedAt: base.startedAt,
      expiresAt: base.expiresAt,
      batteryPercent: base.batteryPercent,
      thermalState: base.thermalState,
      allowedReceiverNodeIds: base.allowedReceiverNodeIds,
      capabilities: base.capabilities,
      lastActivityAt: _lastActivityAt ?? base.lastActivityAt,
      idleTimeout: base.idleTimeout,
      requiresTrustedReceiverScope: base.requiresTrustedReceiverScope,
      isCharging: base.isCharging,
      activeReceiverCount: base.activeReceiverCount,
    );
  }

  void _enforceLifecycle() {
    if (!isRunning) return;
    final snapshot = _effectiveSnapshot();
    final now = _now();
    if (snapshot.isExpired(now) || snapshot.isIdleTimedOut(now)) {
      _emit('session_expired', {'serverId': _initialSnapshot.serverId});
      unawaited(stopServer());
    }
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

  Future<InternetAddress> _lanAddress() async {
    final selected = selectLanAddress(await _interfaceLister());
    if (selected == null) {
      throw StateError(
        'No private LAN address available; refusing to serve media.',
      );
    }
    return selected;
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final response = request.response;
    try {
      if (!_isAuthorizedPath(request.uri.path)) {
        _emit('request_rejected', {'reason': 'unknown_path'});
        response.statusCode = HttpStatus.notFound;
        await response.close();
        return;
      }
      if (request.method != 'GET' && request.method != 'HEAD') {
        _emit('request_rejected', {'reason': 'unsupported_method'});
        response.statusCode = HttpStatus.methodNotAllowed;
        await response.close();
        return;
      }

      final file = File(filePath);
      if (!await file.exists()) {
        response.statusCode = HttpStatus.notFound;
        await response.close();
        return;
      }
      final stat = await file.stat();
      final length = stat.size;
      final etag =
          '"${stat.modified.millisecondsSinceEpoch}-${length.toRadixString(16)}"';

      final decision = await evaluateServing(
        AiroTemporaryMobileServerServingRequest(
          requestId: _generateRequestId(),
          method: request.method == 'HEAD'
              ? AiroTemporaryMobileServerRequestMethod.head
              : AiroTemporaryMobileServerRequestMethod.get,
          receiverNodeId: _initialSnapshot.accessGrant.audienceNodeId,
          now: _now(),
          mediaLengthBytes: length,
          entityValidator: etag,
          // Range-first contract: synthesize a full-entity range for rangeless
          // GETs so thin receivers that skip Range on first fetch still play.
          rangeHeader:
              request.headers.value(HttpHeaders.rangeHeader) ??
              (request.method == 'GET' ? 'bytes=0-' : null),
          // Receiver identity is not verified per-request in this milestone;
          // the session token plus a private-range source address are the
          // effective auth. Local-network scope is derived from the socket.
          hasLocalNetworkScope: _hasPrivateSource(request),
          hasTrustedReceiverScope: true,
          requiresRangeRequest: false,
        ),
      );

      if (!decision.accepted) {
        final rangeNotSatisfiable = decision.servingCodes.contains(
          AiroTemporaryMobileServerServingCode.rangeNotSatisfiable,
        );
        _emit('request_rejected', {
          'validationCodes': decision.validationCodes
              .map((code) => code.stableId)
              .toList(),
          'servingCodes': decision.servingCodes
              .map((code) => code.stableId)
              .toList(),
        });
        if (rangeNotSatisfiable) {
          response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
          response.headers.set(
            HttpHeaders.contentRangeHeader,
            'bytes */$length',
          );
        } else {
          response.statusCode = HttpStatus.forbidden;
        }
        await response.close();
        final expired = decision.validationCodes.any(
          (code) =>
              code == AiroTemporaryMobileServerValidationCode.expired ||
              code ==
                  AiroTemporaryMobileServerValidationCode.idleTimeoutExceeded,
        );
        if (expired) {
          await stopServer();
        }
        return;
      }

      _lastActivityAt = _now();
      final range = decision.range;
      response.statusCode = range == null
          ? HttpStatus.ok
          : HttpStatus.partialContent;
      decision.responseHeaders.forEach(response.headers.set);
      response.headers.contentType = ContentType.parse(contentType);
      // dart:io recomputes Content-Length from the policy-provided header;
      // set explicitly so HEAD responses advertise the entity size.
      response.contentLength = range?.contentLength ?? length;

      if (request.method == 'HEAD') {
        await response.close();
        return;
      }

      final start = range?.start ?? 0;
      final end = range == null ? length : range.end + 1;
      await response.addStream(file.openRead(start, end));
      _lastActivityAt = _now();
      await response.close();
    } catch (error) {
      _emit('request_error', {'error': error.runtimeType.toString()});
      try {
        response.statusCode = HttpStatus.internalServerError;
        await response.close();
      } catch (_) {
        // Socket already gone; nothing to clean up.
      }
    }
  }

  void _emit(String event, Map<String, Object?> data) {
    final handler = onSessionEvent;
    if (handler != null) {
      handler(event, data);
    } else {
      debugPrint('[PhoneMediaServer] $event $data');
    }
  }

  bool _isAuthorizedPath(String path) {
    const prefix = '/m/';
    const suffix = '/media';
    if (path.length < prefix.length + suffix.length) return false;
    if (!path.startsWith(prefix) || !path.endsWith(suffix)) return false;
    final token = path.substring(prefix.length, path.length - suffix.length);
    return _constantTimeEquals(token, _sessionToken);
  }

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var mismatch = 0;
    for (var i = 0; i < a.length; i++) {
      mismatch |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return mismatch == 0;
  }

  static bool _hasPrivateSource(HttpRequest request) {
    final remote = request.connectionInfo?.remoteAddress;
    return remote != null && isPrivateLanAddress(remote);
  }

  static String _generateSessionToken() {
    final random = Random.secure();
    const alphabet = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'
        '0123456789';
    return List.generate(
      32,
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();
  }

  static String _generateRequestId() {
    final random = Random.secure();
    return 'req-${random.nextInt(1 << 32)}';
  }

  @override
  String toString() {
    return 'PhoneMediaFileServer('
        'serverId: ${_initialSnapshot.serverId}, '
        'mediaId: ${_initialSnapshot.mediaId}, '
        'running: $isRunning, '
        'url: redacted, '
        'file: redacted'
        ')';
  }
}
