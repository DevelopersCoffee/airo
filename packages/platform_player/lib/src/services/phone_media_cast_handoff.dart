import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:core_media_routing/core_media_routing.dart';
import 'package:equatable/equatable.dart';

import '../models/cast_models.dart';
import 'airo_cast_controller.dart';
import 'phone_media_file_server.dart';

/// A phone-local media file selected for playback on a receiver (CV-033).
class PhoneLocalMediaItem extends Equatable {
  const PhoneLocalMediaItem({
    required this.filePath,
    required this.title,
    required this.container,
    this.videoCodec,
    this.audioCodec,
    this.duration,
  });

  final String filePath;
  final String title;

  /// Container/extension in lowercase without a dot, e.g. `mp4`, `mkv`.
  final String container;
  final String? videoCodec;
  final String? audioCodec;
  final Duration? duration;

  @override
  List<Object?> get props => [
    filePath,
    title,
    container,
    videoCodec,
    audioCodec,
    duration,
  ];
}

/// Container/codec envelope the target receiver can decode.
///
/// This milestone detects and reports unsupported formats only — transcoding
/// is an explicit future sub-slice of CV-033.
class PhoneMediaReceiverCapabilities extends Equatable {
  const PhoneMediaReceiverCapabilities({
    required this.supportedContainers,
    required this.supportedVideoCodecs,
  });

  static const chromecastDefault = PhoneMediaReceiverCapabilities(
    supportedContainers: {'mp4', 'm4v', 'webm'},
    supportedVideoCodecs: {'h264', 'vp8', 'vp9'},
  );

  final Set<String> supportedContainers;
  final Set<String> supportedVideoCodecs;

  PhoneMediaUnsupportedReason? evaluate(PhoneLocalMediaItem item) {
    if (!supportedContainers.contains(item.container.toLowerCase())) {
      return PhoneMediaUnsupportedReason.container;
    }
    final videoCodec = item.videoCodec?.toLowerCase();
    if (videoCodec != null && !supportedVideoCodecs.contains(videoCodec)) {
      return PhoneMediaUnsupportedReason.videoCodec;
    }
    return null;
  }

  @override
  List<Object?> get props => [supportedContainers, supportedVideoCodecs];
}

enum PhoneMediaUnsupportedReason { container, videoCodec }

sealed class PhoneMediaHandoffResult {
  const PhoneMediaHandoffResult();
}

class PhoneMediaHandoffStarted extends PhoneMediaHandoffResult {
  const PhoneMediaHandoffStarted({required this.request});

  final AiroCastMediaRequest request;
}

class PhoneMediaHandoffUnsupported extends PhoneMediaHandoffResult {
  const PhoneMediaHandoffUnsupported({required this.reason});

  final PhoneMediaUnsupportedReason reason;
}

/// The server could not start or the receiver refused the media load; no
/// server socket is left running.
class PhoneMediaHandoffFailed extends PhoneMediaHandoffResult {
  const PhoneMediaHandoffFailed();
}

/// Streams a phone-local file to the connected receiver through the CV-028
/// cast contract: starts a [PhoneMediaFileServer], hands its tokenized LAN URL
/// to the receiver via [AiroCastController.load], and ties the server's
/// lifetime to the cast session so the socket never outlives playback.
class PhoneMediaCastHandoff {
  PhoneMediaCastHandoff({
    required this._castController,
    this.capabilities = PhoneMediaReceiverCapabilities.chromecastDefault,
    this._bindAddress,
    this.onSessionEvent,
    this._sessionTtl = const Duration(hours: 6),
    this._idleTimeout = const Duration(minutes: 2),
    this._pauseKeepAliveInterval = const Duration(seconds: 30),
  });

  final AiroCastController _castController;
  final PhoneMediaReceiverCapabilities capabilities;
  final InternetAddress? _bindAddress;
  final Duration _sessionTtl;
  final Duration _idleTimeout;

  /// How often to ping the file server's idle clock while the receiver is
  /// paused. Must stay comfortably under [_idleTimeout], since a paused
  /// receiver generates no HTTP traffic of its own.
  final Duration _pauseKeepAliveInterval;
  final void Function(String event, Map<String, Object?> data)? onSessionEvent;

  PhoneMediaFileServer? _server;
  StreamSubscription<AiroCastSessionSnapshot>? _sessionSubscription;
  Timer? _pauseKeepAliveTimer;

  bool get isServing => _server?.isRunning ?? false;

  String? get connectedDeviceName =>
      _castController.currentSessionState.device?.name;

  Future<PhoneMediaHandoffResult> start(PhoneLocalMediaItem item) async {
    final unsupportedReason = capabilities.evaluate(item);
    if (unsupportedReason != null) {
      return PhoneMediaHandoffUnsupported(reason: unsupportedReason);
    }

    _cancelPauseKeepAlive();
    await _teardownServer();

    // Synchronous check: widget tests run in a fake-async zone where real
    // file IO futures never complete before the pump settles.
    if (!File(item.filePath).existsSync()) {
      return const PhoneMediaHandoffFailed();
    }

    final receiverNodeId =
        _castController.currentSessionState.device?.id ?? 'receiver-unknown';
    final server = PhoneMediaFileServer(
      snapshot: _snapshotFor(item, receiverNodeId),
      filePath: item.filePath,
      contentType: _contentTypeFor(item.container),
      bindAddress: _bindAddress,
      onSessionEvent: onSessionEvent,
    );
    _server = server;
    try {
      final mediaUrl = await server.start();

      final request = AiroCastMediaRequest(
        url: mediaUrl,
        contentType: _contentTypeFor(item.container),
        title: item.title,
        streamKind: AiroCastMediaStreamKind.buffered,
        duration: item.duration,
      );

      _sessionSubscription ??= _castController.sessionStateStream.listen(
        _onSessionState,
      );
      await _castController.load(request);
      return PhoneMediaHandoffStarted(request: request);
    } catch (_) {
      // Never leave a live tokenized URL behind a handoff that failed.
      await _teardownServer();
      return const PhoneMediaHandoffFailed();
    }
  }

  Future<void> stopHandoff() async {
    await _castController.stop();
    await _teardownServer();
  }

  Future<void> dispose() async {
    final subscription = _sessionSubscription;
    _sessionSubscription = null;
    _cancelPauseKeepAlive();
    // Tear the server down first: stopServer cancels its lifecycle timer
    // synchronously, so no timer outlives a disposed widget tree.
    final teardown = _teardownServer();
    await subscription?.cancel();
    await teardown;
  }

  void _onSessionState(AiroCastSessionSnapshot snapshot) {
    switch (snapshot.phase) {
      case AiroCastSessionPhase.stopped:
      case AiroCastSessionPhase.disconnected:
      case AiroCastSessionPhase.failed:
      case AiroCastSessionPhase.idle:
        _cancelPauseKeepAlive();
        unawaited(_teardownServer());
      case AiroCastSessionPhase.paused:
        _startPauseKeepAlive();
      case AiroCastSessionPhase.connecting:
      case AiroCastSessionPhase.connected:
      case AiroCastSessionPhase.loadingMedia:
      case AiroCastSessionPhase.playing:
        _cancelPauseKeepAlive();
    }
  }

  // A paused receiver holds the session but sends no HTTP requests, so the
  // file server's own idle-shutdown timer (driven by request traffic) would
  // otherwise mistake "paused" for "abandoned" and kill the socket mid-pause.
  void _startPauseKeepAlive() {
    _pauseKeepAliveTimer ??= Timer.periodic(
      _pauseKeepAliveInterval,
      (_) => _server?.keepAlive(),
    );
  }

  void _cancelPauseKeepAlive() {
    _pauseKeepAliveTimer?.cancel();
    _pauseKeepAliveTimer = null;
  }

  Future<void> _teardownServer() async {
    final server = _server;
    _server = null;
    if (server != null) {
      await server.stopServer();
    }
  }

  AiroTemporaryMobileServerSnapshot _snapshotFor(
    PhoneLocalMediaItem item,
    String receiverNodeId,
  ) {
    final now = DateTime.now();
    final sessionId = _generateId();
    return AiroTemporaryMobileServerSnapshot(
      serverId: 'phone-media-$sessionId',
      hostNodeId: 'phone-host',
      locationId: 'loc-$sessionId',
      mediaId: 'media-$sessionId',
      accessGrant: AiroRouteAccessGrant(
        grantId: 'grant-$sessionId',
        locationId: 'loc-$sessionId',
        audienceNodeId: receiverNodeId,
        handle: AiroRouteAccessHandle.redacted('phone-media-grant-$sessionId'),
        issuedAt: now,
        expiresAt: now.add(_sessionTtl),
        scopes: const {
          AiroRouteAccessScope.playbackRead,
          AiroRouteAccessScope.rangeRead,
          AiroRouteAccessScope.probeRead,
        },
      ),
      startedAt: now,
      expiresAt: now.add(_sessionTtl),
      batteryPercent: 100,
      thermalState: AiroTemporaryMobileThermalState.normal,
      allowedReceiverNodeIds: {receiverNodeId},
      capabilities: const {
        AiroTemporaryMobileServerCapability.lanOnly,
        AiroTemporaryMobileServerCapability.rangeRequests,
        AiroTemporaryMobileServerCapability.probeRequests,
        AiroTemporaryMobileServerCapability.entityValidation,
        AiroTemporaryMobileServerCapability.autoShutdownOnExpiry,
        AiroTemporaryMobileServerCapability.idleShutdown,
      },
      idleTimeout: _idleTimeout,
    );
  }

  static String _contentTypeFor(String container) {
    switch (container.toLowerCase()) {
      case 'mp4':
      case 'm4v':
        return 'video/mp4';
      case 'webm':
        return 'video/webm';
      case 'mkv':
        return 'video/x-matroska';
      default:
        return 'application/octet-stream';
    }
  }

  static String _generateId() {
    final random = Random.secure();
    return random.nextInt(1 << 32).toRadixString(16);
  }
}
