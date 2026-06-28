import 'dart:async';
import 'dart:io';

import 'package:flutter_chrome_cast/cast_context.dart';
import 'package:flutter_chrome_cast/common.dart';
import 'package:flutter_chrome_cast/discovery.dart';
import 'package:flutter_chrome_cast/entities.dart';
import 'package:flutter_chrome_cast/enums.dart';
import 'package:flutter_chrome_cast/media.dart';
import 'package:flutter_chrome_cast/session.dart';

import 'cast_controller.dart';
import 'cast_models.dart';

class FlutterChromeCastController implements AiroCastController {
  FlutterChromeCastController();

  static const defaultReceiverApplicationId =
      GoogleCastDiscoveryCriteria.kDefaultApplicationId;

  final _discoveryController =
      StreamController<AiroCastDiscoveryState>.broadcast();
  final _sessionController =
      StreamController<AiroCastSessionSnapshot>.broadcast();

  final Map<String, GoogleCastDevice> _pluginDevicesByAiroId = {};
  StreamSubscription<List<GoogleCastDevice>>? _devicesSubscription;
  StreamSubscription<GoogleCastSession?>? _sessionSubscription;
  StreamSubscription<GoggleCastMediaStatus?>? _mediaStatusSubscription;

  AiroCastDiscoveryState _discoveryState = const AiroCastDiscoveryState.idle();
  AiroCastSessionSnapshot _sessionState = const AiroCastSessionSnapshot.idle();
  AiroCastDevice? _connectedDevice;
  AiroCastMediaRequest? _currentMediaRequest;
  bool _initialized = false;

  @override
  Stream<AiroCastDiscoveryState> get discoveryStateStream =>
      _discoveryController.stream;

  @override
  Stream<AiroCastSessionSnapshot> get sessionStateStream =>
      _sessionController.stream;

  @override
  AiroCastDiscoveryState get currentDiscoveryState => _discoveryState;

  @override
  AiroCastSessionSnapshot get currentSessionState => _sessionState;

  @override
  Future<void> initialize() async {
    if (!_isSupportedPlatform) {
      _setSession(
        const AiroCastSessionSnapshot.failed(
          AiroCastError(
            code: AiroCastErrorCode.platformUnavailable,
            message: 'Google Cast is only available on Android and iOS.',
          ),
        ),
      );
      return;
    }

    if (_initialized) return;

    try {
      await GoogleCastContext.instance.setSharedInstanceWithOptions(
        GoogleCastOptions(
          disableDiscoveryAutostart: true,
          startDiscoveryAfterFirstTapOnCastButton: false,
          stopReceiverApplicationWhenEndingSession: false,
        ),
      );
      _listenToPluginStreams();
      _initialized = true;
    } catch (error) {
      _setSession(
        AiroCastSessionSnapshot.failed(
          AiroCastError(
            code: AiroCastErrorCode.platformUnavailable,
            message: 'Unable to initialize Google Cast: $error',
          ),
        ),
      );
    }
  }

  @override
  Future<void> startDiscovery() async {
    if (!await _ensureInitialized()) return;

    try {
      _setDiscovery(
        AiroCastDiscoveryState.discovering(devices: _discoveryState.devices),
      );
      await GoogleCastDiscoveryManager.instance.startDiscovery();
      _updateDevices(GoogleCastDiscoveryManager.instance.devices);
    } catch (error) {
      _setDiscovery(
        AiroCastDiscoveryState.failed('Cast discovery failed: $error'),
      );
    }
  }

  @override
  Future<void> stopDiscovery() async {
    if (!_isSupportedPlatform) return;

    try {
      await GoogleCastDiscoveryManager.instance.stopDiscovery();
    } finally {
      _setDiscovery(const AiroCastDiscoveryState.idle());
    }
  }

  @override
  Future<void> connect(AiroCastDevice device) async {
    if (!await _ensureInitialized()) return;

    final pluginDevice = _pluginDevicesByAiroId[device.id];
    if (pluginDevice == null) {
      _setSession(
        const AiroCastSessionSnapshot.failed(
          AiroCastError(
            code: AiroCastErrorCode.receiverUnavailable,
            message: 'The selected Cast receiver is no longer available.',
          ),
        ),
      );
      return;
    }

    try {
      final previousDevice = _connectedDevice;
      if (previousDevice != null && previousDevice.id != device.id) {
        await GoogleCastSessionManager.instance.endSessionAndStopCasting();
        _connectedDevice = null;
        _currentMediaRequest = null;
      }

      _setSession(AiroCastSessionSnapshot.connecting(device));
      final didStart = await GoogleCastSessionManager.instance
          .startSessionWithDevice(pluginDevice);
      if (!didStart) {
        _setSession(
          const AiroCastSessionSnapshot.failed(
            AiroCastError(
              code: AiroCastErrorCode.connectionTimeout,
              message: 'Unable to start a Cast session with this receiver.',
            ),
          ),
        );
        return;
      }

      _connectedDevice = device;
      _setSession(AiroCastSessionSnapshot.connected(device));
    } catch (error) {
      _setSession(
        AiroCastSessionSnapshot.failed(
          AiroCastError(
            code: AiroCastErrorCode.connectionTimeout,
            message: 'Unable to connect to Cast receiver: $error',
          ),
        ),
      );
    }
  }

  @override
  Future<void> load(AiroCastMediaRequest request) async {
    if (!await _ensureInitialized()) return;

    final device = _connectedDevice ?? _sessionState.device;
    if (device == null) {
      _setSession(
        const AiroCastSessionSnapshot.failed(
          AiroCastError(
            code: AiroCastErrorCode.receiverUnavailable,
            message: 'Choose a Cast device before loading media.',
          ),
        ),
      );
      return;
    }

    try {
      _currentMediaRequest = request;
      _setSession(
        AiroCastSessionSnapshot.loadingMedia(device: device, media: request),
      );
      await GoogleCastRemoteMediaClient.instance.loadMedia(
        toGoogleMediaInfo(request),
      );
      _setSession(
        AiroCastSessionSnapshot.playing(
          device: device,
          media: request,
          volume: _sessionState.volume,
        ),
      );
    } catch (error) {
      _setSession(
        AiroCastSessionSnapshot.failed(
          AiroCastError(
            code: AiroCastErrorCode.mediaLoadFailed,
            message: 'The receiver could not load this media: $error',
          ),
        ),
      );
    }
  }

  @override
  Future<void> play() async {
    if (!await _ensureInitialized()) return;

    await GoogleCastRemoteMediaClient.instance.play();
    final device = _sessionState.device;
    final media = _currentMediaRequest ?? _sessionState.media;
    if (device != null && media != null) {
      _setSession(
        AiroCastSessionSnapshot.playing(
          device: device,
          media: media,
          volume: _sessionState.volume,
        ),
      );
    }
  }

  @override
  Future<void> pause() async {
    if (!await _ensureInitialized()) return;

    await GoogleCastRemoteMediaClient.instance.pause();
    final device = _sessionState.device;
    final media = _currentMediaRequest ?? _sessionState.media;
    if (device != null && media != null) {
      _setSession(
        AiroCastSessionSnapshot.paused(
          device: device,
          media: media,
          volume: _sessionState.volume,
        ),
      );
    }
  }

  @override
  Future<void> stop() async {
    if (!await _ensureInitialized()) return;

    await GoogleCastRemoteMediaClient.instance.stop();
    _currentMediaRequest = null;
    _setSession(const AiroCastSessionSnapshot.stopped());
  }

  @override
  Future<void> setVolume(double volume) async {
    if (!await _ensureInitialized()) return;

    final clampedVolume = volume.clamp(0.0, 1.0).toDouble();
    GoogleCastSessionManager.instance.setDeviceVolume(clampedVolume);
    _updateVolume(clampedVolume);
  }

  @override
  Future<void> disconnect() async {
    if (!_isSupportedPlatform) return;

    final device = _connectedDevice ?? _sessionState.device;
    await GoogleCastSessionManager.instance.endSessionAndStopCasting();
    _connectedDevice = null;
    _currentMediaRequest = null;
    if (device != null) {
      _setSession(AiroCastSessionSnapshot.disconnected(device));
    } else {
      _setSession(const AiroCastSessionSnapshot.idle());
    }
  }

  @override
  Future<void> dispose() async {
    await _devicesSubscription?.cancel();
    await _sessionSubscription?.cancel();
    await _mediaStatusSubscription?.cancel();
    await _discoveryController.close();
    await _sessionController.close();
  }

  static GoogleCastMediaInformation toGoogleMediaInfo(
    AiroCastMediaRequest request,
  ) {
    return GoogleCastMediaInformation(
      contentId: request.url.toString(),
      contentUrl: request.url,
      contentType: request.contentType,
      streamType: switch (request.streamKind) {
        AiroCastMediaStreamKind.live => CastMediaStreamType.live,
        AiroCastMediaStreamKind.buffered => CastMediaStreamType.buffered,
      },
      duration: request.duration,
      metadata: GoogleCastGenericMediaMetadata(
        title: request.title,
        subtitle: request.subtitle,
        images: request.imageUrl == null
            ? null
            : [GoogleCastImage(url: request.imageUrl!)],
      ),
    );
  }

  bool get _isSupportedPlatform => Platform.isAndroid || Platform.isIOS;

  Future<bool> _ensureInitialized() async {
    if (!_isSupportedPlatform) {
      _setSession(
        const AiroCastSessionSnapshot.failed(
          AiroCastError(
            code: AiroCastErrorCode.platformUnavailable,
            message: 'Google Cast is only available on Android and iOS.',
          ),
        ),
      );
      return false;
    }
    if (!_initialized) {
      await initialize();
    }
    return _initialized;
  }

  void _listenToPluginStreams() {
    _devicesSubscription ??= GoogleCastDiscoveryManager.instance.devicesStream
        .listen(
          _updateDevices,
          onError: (Object error) {
            _setDiscovery(
              AiroCastDiscoveryState.failed('Cast discovery failed: $error'),
            );
          },
        );

    _sessionSubscription ??= GoogleCastSessionManager
        .instance
        .currentSessionStream
        .listen(
          _updateSession,
          onError: (Object error) {
            _setSession(
              AiroCastSessionSnapshot.failed(
                AiroCastError(
                  code: AiroCastErrorCode.receiverDisconnected,
                  message: 'Cast session failed: $error',
                ),
              ),
            );
          },
        );

    _mediaStatusSubscription ??= GoogleCastRemoteMediaClient
        .instance
        .mediaStatusStream
        .listen(
          _updateMediaStatus,
          onError: (Object error) {
            _setSession(
              AiroCastSessionSnapshot.failed(
                AiroCastError(
                  code: AiroCastErrorCode.mediaLoadFailed,
                  message: 'Cast media status failed: $error',
                ),
              ),
            );
          },
        );
  }

  void _updateDevices(List<GoogleCastDevice> pluginDevices) {
    _pluginDevicesByAiroId
      ..clear()
      ..addEntries(
        pluginDevices.map((device) {
          final airoDevice = _toAiroDevice(device);
          return MapEntry(airoDevice.id, device);
        }),
      );

    final devices = pluginDevices.map(_toAiroDevice).toList(growable: false);
    if (devices.isEmpty) {
      _setDiscovery(const AiroCastDiscoveryState.noDevices());
    } else {
      _setDiscovery(AiroCastDiscoveryState.found(devices));
    }
  }

  void _updateSession(GoogleCastSession? session) {
    if (session == null) {
      final device = _connectedDevice;
      _connectedDevice = null;
      _currentMediaRequest = null;
      if (device != null) {
        _setSession(AiroCastSessionSnapshot.disconnected(device));
      }
      return;
    }

    final device = session.device == null
        ? _connectedDevice
        : _toAiroDevice(session.device!);
    if (device == null) return;

    _connectedDevice = device;
    switch (session.connectionState) {
      case GoogleCastConnectState.connecting:
        _setSession(AiroCastSessionSnapshot.connecting(device));
      case GoogleCastConnectState.connected:
        _setSession(AiroCastSessionSnapshot.connected(device));
        _updateVolume(session.currentDeviceVolume);
      case GoogleCastConnectState.disconnecting:
      case GoogleCastConnectState.disconnected:
        _connectedDevice = null;
        _currentMediaRequest = null;
        _setSession(AiroCastSessionSnapshot.disconnected(device));
    }
  }

  void _updateMediaStatus(GoggleCastMediaStatus? status) {
    if (status == null) return;

    final device = _connectedDevice ?? _sessionState.device;
    final media = _currentMediaRequest ?? _sessionState.media;
    if (device == null || media == null) return;

    final volume = status.volume.toDouble().clamp(0.0, 1.0).toDouble();
    switch (status.playerState) {
      case CastMediaPlayerState.playing:
        _setSession(
          AiroCastSessionSnapshot.playing(
            device: device,
            media: media,
            volume: volume,
          ),
        );
      case CastMediaPlayerState.paused:
        _setSession(
          AiroCastSessionSnapshot.paused(
            device: device,
            media: media,
            volume: volume,
          ),
        );
      case CastMediaPlayerState.loading:
      case CastMediaPlayerState.buffering:
        _setSession(
          AiroCastSessionSnapshot.loadingMedia(device: device, media: media),
        );
      case CastMediaPlayerState.idle:
      case CastMediaPlayerState.unknown:
        _setSession(const AiroCastSessionSnapshot.stopped());
    }
  }

  AiroCastDevice _toAiroDevice(GoogleCastDevice device) {
    final id = device.uniqueID.isNotEmpty ? device.uniqueID : device.deviceID;
    return AiroCastDevice(
      id: id,
      name: device.friendlyName,
      modelName: device.modelName,
      lastSeenAt: DateTime.now(),
    );
  }

  void _updateVolume(double volume) {
    final snapshot = _sessionState;
    final device = snapshot.device;
    final media = snapshot.media;
    final clampedVolume = volume.clamp(0.0, 1.0).toDouble();
    if (device == null || media == null) return;

    if (snapshot.phase == AiroCastSessionPhase.paused) {
      _setSession(
        AiroCastSessionSnapshot.paused(
          device: device,
          media: media,
          volume: clampedVolume,
        ),
      );
    } else {
      _setSession(
        AiroCastSessionSnapshot.playing(
          device: device,
          media: media,
          volume: clampedVolume,
        ),
      );
    }
  }

  void _setDiscovery(AiroCastDiscoveryState state) {
    _discoveryState = state;
    _discoveryController.add(state);
  }

  void _setSession(AiroCastSessionSnapshot state) {
    _sessionState = state;
    _sessionController.add(state);
  }
}
