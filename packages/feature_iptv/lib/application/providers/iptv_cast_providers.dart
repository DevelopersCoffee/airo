import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import "package:platform_channels/platform_channels.dart";
import "package:platform_player/platform_player.dart";

final airoCastControllerProvider = Provider<AiroCastController>((ref) {
  final controller = UnavailableAiroCastController();
  ref.onDispose(() {
    unawaited(controller.dispose());
  });
  return controller;
});

final iptvCastMediaAdapterProvider = Provider<IptvCastMediaAdapter>((ref) {
  return const IptvCastMediaAdapter();
});

final iptvCastProvider = StateNotifierProvider<IptvCastNotifier, IptvCastState>(
  (ref) {
    return IptvCastNotifier(
      controller: ref.watch(airoCastControllerProvider),
      adapter: ref.watch(iptvCastMediaAdapterProvider),
    );
  },
);

class IptvCastState extends Equatable {
  final AiroCastDiscoveryState discovery;
  final AiroCastSessionSnapshot session;
  final AiroCastError? lastError;

  const IptvCastState({
    this.discovery = const AiroCastDiscoveryState.idle(),
    this.session = const AiroCastSessionSnapshot.idle(),
    this.lastError,
  });

  bool get isCasting => session.isConnected;
  AiroCastDevice? get activeDevice => session.device;

  IptvCastState copyWith({
    AiroCastDiscoveryState? discovery,
    AiroCastSessionSnapshot? session,
    AiroCastError? lastError,
    bool clearError = false,
  }) {
    return IptvCastState(
      discovery: discovery ?? this.discovery,
      session: session ?? this.session,
      lastError: clearError ? null : lastError ?? this.lastError,
    );
  }

  @override
  List<Object?> get props => [discovery, session, lastError];
}

class IptvCastNotifier extends StateNotifier<IptvCastState> {
  IptvCastNotifier({required this.controller, required this.adapter})
    : super(const IptvCastState()) {
    _discoverySubscription = controller.discoveryStateStream.listen((value) {
      state = state.copyWith(discovery: value);
    });
    _sessionSubscription = controller.sessionStateStream.listen((value) {
      state = state.copyWith(session: value);
      if (value.error != null) {
        state = state.copyWith(lastError: value.error);
      }
    });
  }

  final AiroCastController controller;
  final IptvCastMediaAdapter adapter;
  StreamSubscription<AiroCastDiscoveryState>? _discoverySubscription;
  StreamSubscription<AiroCastSessionSnapshot>? _sessionSubscription;
  int _castRequestGeneration = 0;

  Future<void> initialize() => controller.initialize();

  Future<void> startDiscovery() async {
    state = state.copyWith(clearError: true);
    await controller.initialize();
    await controller.startDiscovery();
    state = state.copyWith(discovery: controller.currentDiscoveryState);
  }

  Future<void> stopDiscovery() async {
    await controller.stopDiscovery();
    state = state.copyWith(discovery: controller.currentDiscoveryState);
  }

  Future<void> castChannelToDevice({
    required IPTVChannel channel,
    required AiroCastDevice device,
    VideoQuality selectedQuality = VideoQuality.auto,
  }) async {
    final generation = ++_castRequestGeneration;
    state = state.copyWith(clearError: true);
    final result = adapter.toCastRequest(
      channel,
      selectedQuality: selectedQuality,
    );
    if (!result.isCastable) {
      state = state.copyWith(lastError: result.error);
      return;
    }

    await controller.connect(device);
    if (!_isCurrentCastRequest(generation)) return;
    if (controller.currentSessionState.phase == AiroCastSessionPhase.failed) {
      state = state.copyWith(
        session: controller.currentSessionState,
        lastError: controller.currentSessionState.error,
      );
      return;
    }

    await controller.load(result.request!);
    if (!_isCurrentCastRequest(generation)) return;
    state = state.copyWith(session: controller.currentSessionState);
    final error = controller.currentSessionState.error;
    if (error != null) {
      state = state.copyWith(lastError: error);
    }
  }

  Future<void> castChannelToActiveDevice({
    required IPTVChannel channel,
    VideoQuality selectedQuality = VideoQuality.auto,
  }) async {
    final generation = ++_castRequestGeneration;
    state = state.copyWith(clearError: true);
    final device = state.activeDevice;
    if (device == null) {
      state = state.copyWith(
        lastError: const AiroCastError(
          code: AiroCastErrorCode.receiverUnavailable,
          message: 'Choose a Cast device before casting this channel.',
        ),
      );
      return;
    }

    final result = adapter.toCastRequest(
      channel,
      selectedQuality: selectedQuality,
    );
    if (!result.isCastable) {
      state = state.copyWith(lastError: result.error);
      return;
    }

    await controller.load(result.request!);
    if (!_isCurrentCastRequest(generation)) return;
    state = state.copyWith(session: controller.currentSessionState);
    final error = controller.currentSessionState.error;
    if (error != null) {
      state = state.copyWith(lastError: error);
    }
  }

  Future<void> play() async {
    await controller.play();
    _syncSessionFromController();
  }

  Future<void> pause() async {
    await controller.pause();
    _syncSessionFromController();
  }

  Future<void> stop() async {
    _castRequestGeneration++;
    await controller.stop();
    _syncSessionFromController();
  }

  Future<void> reloadActiveMedia() async {
    final generation = ++_castRequestGeneration;
    state = state.copyWith(clearError: true);
    final media = state.session.media;
    if (state.activeDevice == null || media == null) {
      state = state.copyWith(
        lastError: const AiroCastError(
          code: AiroCastErrorCode.receiverUnavailable,
          message: 'Choose a Cast device before restarting playback.',
        ),
      );
      return;
    }

    await controller.load(media);
    if (!_isCurrentCastRequest(generation)) return;
    _syncSessionFromController();
  }

  Future<void> restartActiveSession() async {
    final generation = ++_castRequestGeneration;
    state = state.copyWith(clearError: true);
    final device = state.activeDevice;
    final media = state.session.media;
    if (device == null || media == null) {
      state = state.copyWith(
        lastError: const AiroCastError(
          code: AiroCastErrorCode.receiverUnavailable,
          message: 'Choose a Cast device before starting a new session.',
        ),
      );
      return;
    }

    await controller.disconnect();
    if (!_isCurrentCastRequest(generation)) return;
    await controller.connect(device);
    if (!_isCurrentCastRequest(generation)) return;
    if (controller.currentSessionState.phase == AiroCastSessionPhase.failed) {
      _syncSessionFromController();
      return;
    }

    await controller.load(media);
    if (!_isCurrentCastRequest(generation)) return;
    _syncSessionFromController();
  }

  Future<void> disconnect() async {
    _castRequestGeneration++;
    await controller.disconnect();
    _syncSessionFromController();
  }

  Future<void> setVolume(double volume) async {
    await controller.setVolume(volume);
    _syncSessionFromController();
  }

  bool _isCurrentCastRequest(int generation) {
    return generation == _castRequestGeneration;
  }

  void _syncSessionFromController() {
    state = state.copyWith(session: controller.currentSessionState);
    final error = controller.currentSessionState.error;
    if (error != null) {
      state = state.copyWith(lastError: error);
    }
  }

  @override
  void dispose() {
    _discoverySubscription?.cancel();
    _sessionSubscription?.cancel();
    super.dispose();
  }
}
