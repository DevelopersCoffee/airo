import 'package:equatable/equatable.dart';

enum AiroCastDiscoveryPhase {
  idle,
  permissionRequired,
  discovering,
  found,
  noDevices,
  failed,
}

enum AiroCastSessionPhase {
  idle,
  connecting,
  connected,
  loadingMedia,
  playing,
  paused,
  stopped,
  disconnected,
  failed,
}

enum AiroCastMediaStreamKind { live, buffered }

enum AiroCastErrorCode {
  permissionDenied,
  discoveryFailed,
  noDevicesFound,
  connectionTimeout,
  receiverUnavailable,
  mediaLoadFailed,
  unsupportedStream,
  receiverDisconnected,
  platformUnavailable,
}

class AiroCastDevice extends Equatable {
  final String id;
  final String name;
  final String? modelName;
  final String? host;
  final int? port;
  final DateTime? lastSeenAt;

  const AiroCastDevice({
    required this.id,
    required this.name,
    this.modelName,
    this.host,
    this.port,
    this.lastSeenAt,
  });

  @override
  List<Object?> get props => [id];
}

class AiroCastError extends Equatable {
  final AiroCastErrorCode code;
  final String message;

  const AiroCastError({required this.code, required this.message});

  @override
  List<Object?> get props => [code, message];
}

class AiroCastDiscoveryState extends Equatable {
  final AiroCastDiscoveryPhase phase;
  final List<AiroCastDevice> devices;
  final String? error;

  const AiroCastDiscoveryState._({
    required this.phase,
    this.devices = const [],
    this.error,
  });

  const AiroCastDiscoveryState.idle()
    : this._(phase: AiroCastDiscoveryPhase.idle);

  const AiroCastDiscoveryState.permissionRequired()
    : this._(phase: AiroCastDiscoveryPhase.permissionRequired);

  factory AiroCastDiscoveryState.discovering({
    List<AiroCastDevice> devices = const [],
  }) {
    return AiroCastDiscoveryState._(
      phase: AiroCastDiscoveryPhase.discovering,
      devices: List.unmodifiable(devices),
    );
  }

  factory AiroCastDiscoveryState.found(List<AiroCastDevice> devices) {
    return AiroCastDiscoveryState._(
      phase: AiroCastDiscoveryPhase.found,
      devices: List.unmodifiable(devices),
    );
  }

  const AiroCastDiscoveryState.noDevices()
    : this._(phase: AiroCastDiscoveryPhase.noDevices);

  factory AiroCastDiscoveryState.failed(String error) {
    return AiroCastDiscoveryState._(
      phase: AiroCastDiscoveryPhase.failed,
      error: error,
    );
  }

  @override
  List<Object?> get props => [phase, devices, error];
}

class AiroCastMediaRequest extends Equatable {
  final Uri url;
  final String contentType;
  final String title;
  final String? subtitle;
  final Uri? imageUrl;
  final AiroCastMediaStreamKind streamKind;
  final Duration? duration;

  const AiroCastMediaRequest({
    required this.url,
    required this.contentType,
    required this.title,
    this.subtitle,
    this.imageUrl,
    this.streamKind = AiroCastMediaStreamKind.live,
    this.duration,
  });

  @override
  List<Object?> get props => [
    url,
    contentType,
    title,
    subtitle,
    imageUrl,
    streamKind,
    duration,
  ];
}

class AiroCastSessionSnapshot extends Equatable {
  final AiroCastSessionPhase phase;
  final AiroCastDevice? device;
  final AiroCastMediaRequest? media;
  final AiroCastError? error;
  final double volume;

  const AiroCastSessionSnapshot._({
    required this.phase,
    this.device,
    this.media,
    this.error,
    this.volume = 1.0,
  });

  const AiroCastSessionSnapshot.idle()
    : this._(phase: AiroCastSessionPhase.idle);

  const AiroCastSessionSnapshot.connecting(AiroCastDevice device)
    : this._(phase: AiroCastSessionPhase.connecting, device: device);

  const AiroCastSessionSnapshot.connected(AiroCastDevice device)
    : this._(phase: AiroCastSessionPhase.connected, device: device);

  const AiroCastSessionSnapshot.loadingMedia({
    required AiroCastDevice device,
    required AiroCastMediaRequest media,
  }) : this._(
         phase: AiroCastSessionPhase.loadingMedia,
         device: device,
         media: media,
       );

  const AiroCastSessionSnapshot.playing({
    required AiroCastDevice device,
    required AiroCastMediaRequest media,
    double volume = 1.0,
  }) : this._(
         phase: AiroCastSessionPhase.playing,
         device: device,
         media: media,
         volume: volume,
       );

  const AiroCastSessionSnapshot.paused({
    required AiroCastDevice device,
    required AiroCastMediaRequest media,
    double volume = 1.0,
  }) : this._(
         phase: AiroCastSessionPhase.paused,
         device: device,
         media: media,
         volume: volume,
       );

  const AiroCastSessionSnapshot.stopped()
    : this._(phase: AiroCastSessionPhase.stopped);

  const AiroCastSessionSnapshot.disconnected(AiroCastDevice device)
    : this._(phase: AiroCastSessionPhase.disconnected, device: device);

  const AiroCastSessionSnapshot.failed(AiroCastError error)
    : this._(phase: AiroCastSessionPhase.failed, error: error);

  bool get hasActiveDevice => device != null;
  bool get isConnected =>
      phase == AiroCastSessionPhase.connected ||
      phase == AiroCastSessionPhase.loadingMedia ||
      phase == AiroCastSessionPhase.playing ||
      phase == AiroCastSessionPhase.paused;

  @override
  List<Object?> get props => [phase, device, media, error, volume];
}
