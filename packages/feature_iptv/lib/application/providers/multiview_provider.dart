import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_media/platform_media.dart';
import 'package:platform_player/platform_player.dart';

import 'iptv_providers.dart';

typedef IptvMultiviewSessionFactory =
    Future<IptvMultiviewSession> Function(IPTVChannel channel);

abstract interface class IptvMultiviewSession implements AiroMultiviewSession {
  IPTVChannel get channel;

  Stream<StreamingState> get states;

  StreamingState get currentState;

  Widget? buildView();

  Future<void> selectTrack({
    required AiroPlaybackTrackKind kind,
    required String trackId,
  });

  Future<void> clearTrackSelection(AiroPlaybackTrackKind kind);

  Future<void> setQuality(VideoQuality quality);
}

enum MultiviewToggleResult { added, removed, capacityReached, failed }

class MultiviewState {
  const MultiviewState({
    this.sessions = const [],
    this.featuredChannelId,
    required this.capacity,
  });

  final List<IptvMultiviewSession> sessions;
  final String? featuredChannelId;
  final int capacity;

  bool contains(String channelId) =>
      sessions.any((session) => session.id == channelId);
}

class MultiviewController extends StateNotifier<MultiviewState> {
  MultiviewController({
    required int decoderBudget,
    required IptvMultiviewSessionFactory sessionFactory,
    required IPTVStreamingService primaryService,
  }) : // Public constructor labels intentionally omit private field names.
       // ignore: prefer_initializing_formals
       _sessionFactory = sessionFactory,
       // ignore: prefer_initializing_formals
       _primaryService = primaryService,
       super(
         MultiviewState(
           capacity: decoderBudget.clamp(1, kAiroMultiviewHardCap),
         ),
       ) {
    _pool = AiroMultiviewPool(
      decoderBudget: decoderBudget,
      onChanged: _syncFromPool,
    );
  }

  final IptvMultiviewSessionFactory _sessionFactory;
  final IPTVStreamingService _primaryService;
  late final AiroMultiviewPool _pool;
  bool _primaryPausedByMultiview = false;
  bool _disposed = false;

  Future<MultiviewToggleResult> toggle(IPTVChannel channel) async {
    if (_pool.state.contains(channel.id)) {
      await _pool.remove(channel.id);
      if (_pool.state.count == 0) await _resumePrimary();
      return MultiviewToggleResult.removed;
    }

    final firstSession = _pool.state.count == 0;
    if (firstSession) {
      _primaryPausedByMultiview = _primaryService.currentState.isPlaying;
      if (_primaryPausedByMultiview) await _primaryService.pause();
    }
    final result = await _pool.add(
      id: channel.id,
      openSession: () => _sessionFactory(channel),
    );
    if (result != AiroMultiviewAddResult.added && firstSession) {
      await _resumePrimary();
    }
    return switch (result) {
      AiroMultiviewAddResult.added => MultiviewToggleResult.added,
      AiroMultiviewAddResult.capacityReached =>
        MultiviewToggleResult.capacityReached,
      AiroMultiviewAddResult.alreadyPresent ||
      AiroMultiviewAddResult.openFailed => MultiviewToggleResult.failed,
    };
  }

  Future<void> promote(String channelId) => _pool.promote(channelId);

  void swap(String firstChannelId, String secondChannelId) =>
      _pool.swap(firstChannelId, secondChannelId);

  Future<void> close() async {
    if (_disposed) return;
    _disposed = true;
    await _pool.close();
    await _resumePrimary();
  }

  void _syncFromPool(AiroMultiviewPoolState poolState) {
    if (_disposed) return;
    state = MultiviewState(
      sessions: List.unmodifiable(
        poolState.sessions.cast<IptvMultiviewSession>(),
      ),
      featuredChannelId: poolState.featuredSessionId,
      capacity: _pool.capacity,
    );
  }

  Future<void> _resumePrimary() async {
    if (!_primaryPausedByMultiview) return;
    _primaryPausedByMultiview = false;
    await _primaryService.resume();
  }

  @override
  void dispose() {
    unawaited(close());
    super.dispose();
  }
}

final multiviewDecoderBudgetProvider = Provider<int>((ref) {
  if (kIsWeb) return 2;
  return switch (defaultTargetPlatform) {
    TargetPlatform.android || TargetPlatform.iOS => 2,
    TargetPlatform.macOS || TargetPlatform.windows || TargetPlatform.linux => 4,
    TargetPlatform.fuchsia => 1,
  };
});

final iptvMultiviewSessionFactoryProvider =
    Provider<IptvMultiviewSessionFactory>((ref) {
      return (channel) async {
        final service = VideoPlayerStreamingService(
          config: StreamingConfig.live,
        );
        try {
          await service.initialize();
          await service.setVolume(0);
          await service.playChannel(channel);
          if (service.currentState.hasError) {
            throw StateError('Multiview channel failed to open');
          }
          return _VideoPlayerMultiviewSession(
            channel: channel,
            service: service,
          );
        } catch (_) {
          await service.dispose();
          rethrow;
        }
      };
    });

final multiviewProvider =
    StateNotifierProvider<MultiviewController, MultiviewState>((ref) {
      final controller = MultiviewController(
        decoderBudget: ref.watch(multiviewDecoderBudgetProvider),
        sessionFactory: ref.watch(iptvMultiviewSessionFactoryProvider),
        primaryService: ref.watch(iptvStreamingServiceProvider),
      );
      return controller;
    });

class _VideoPlayerMultiviewSession implements IptvMultiviewSession {
  _VideoPlayerMultiviewSession({
    required this.channel,
    required VideoPlayerStreamingService service,
  }) : // Keep the factory-facing label independent of the private field.
       // ignore: prefer_initializing_formals
       _service = service;

  @override
  final IPTVChannel channel;
  final VideoPlayerStreamingService _service;

  @override
  String get id => channel.id;

  @override
  Stream<StreamingState> get states => _service.stateStream;

  @override
  StreamingState get currentState => _service.currentState;

  @override
  Widget? buildView() => _service.buildVideoView();

  @override
  Future<void> selectTrack({
    required AiroPlaybackTrackKind kind,
    required String trackId,
  }) => _service.selectTrack(kind: kind, trackId: trackId);

  @override
  Future<void> clearTrackSelection(AiroPlaybackTrackKind kind) =>
      _service.clearTrackSelection(kind);

  @override
  Future<void> setQuality(VideoQuality quality) => _service.setQuality(quality);

  @override
  Future<void> setAudible(bool audible) async {
    try {
      await _service.setVolume(audible ? 1 : 0);
    } catch (_) {
      // Pool invariants and cleanup continue after a backend volume failure.
    }
  }

  @override
  Future<void> close() async {
    try {
      await _service.stop();
    } finally {
      await _service.dispose();
    }
  }
}
