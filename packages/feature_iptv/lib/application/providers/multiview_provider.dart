import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_media/platform_media.dart';
import 'package:platform_player/platform_player.dart';

import '../multiview_split_ratio.dart';
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
    this.layout,
    this.splitRatio = MultiviewSplitRatio.fifty,
  });

  final List<IptvMultiviewSession> sessions;
  final String? featuredChannelId;
  final int capacity;
  final MultiviewLayoutKind? layout;
  final MultiviewSplitRatio splitRatio;

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
  bool _primaryHeldByMultiview = false;
  IPTVChannel? _primaryChannelHeldForMultiview;
  double _primaryVolumeHeldForMultiview = 1;
  double _lastSplitExtent = 1600;
  int _mixGeneration = 0;
  bool _disposed = false;

  /// `StateNotifier.state` is protected — this is the public read a
  /// non-widget listener (e.g. `CastMultiviewReceiverBridge`) needs for an
  /// eager snapshot instead of waiting for the next [stream] event.
  MultiviewState get currentState => state;

  Future<MultiviewToggleResult> toggle(IPTVChannel channel) async {
    if (_pool.state.contains(channel.id)) {
      await _pool.remove(channel.id);
      if (_pool.state.count == 0) await _resumePrimary();
      _scheduleTwoPaneMix();
      return MultiviewToggleResult.removed;
    }

    final firstSession = _pool.state.count == 0;
    if (firstSession) {
      await _holdPrimaryForMultiview();
    }
    final result = await _pool.add(
      id: channel.id,
      openSession: () => _sessionFactory(channel),
    );
    if (result != AiroMultiviewAddResult.added && firstSession) {
      await _resumePrimary();
    } else if (result == AiroMultiviewAddResult.added && firstSession) {
      await _releasePrimaryDecoder();
    }
    _scheduleTwoPaneMix();
    return switch (result) {
      AiroMultiviewAddResult.added => MultiviewToggleResult.added,
      AiroMultiviewAddResult.capacityReached =>
        MultiviewToggleResult.capacityReached,
      AiroMultiviewAddResult.alreadyPresent ||
      AiroMultiviewAddResult.openFailed => MultiviewToggleResult.failed,
    };
  }

  /// Swaps out an already-open multiview session for a different channel.
  ///
  /// Used from the capacity-reached flow, where the user picks an existing
  /// tile to replace instead of adding a new one. This is intentionally NOT
  /// an atomic swap: [oldChannelId]'s session is torn down first (freeing a
  /// pool slot), then the new channel is opened. If the new stream fails to
  /// open, the freed slot stays empty -- the old session is not reopened.
  ///
  /// Does not touch `_primaryHeldByMultiview`: `replace()` only ever runs
  /// while at least one multiview session is already active (that's how the
  /// capacity-reached dialog gets triggered), so the primary-pause-on-first-
  /// session bookkeeping in [toggle] never applies here.
  Future<MultiviewToggleResult> replace(
    String oldChannelId,
    IPTVChannel newChannel,
  ) async {
    if (_pool.state.contains(oldChannelId)) {
      await _pool.remove(oldChannelId);
    }
    final result = await _pool.add(
      id: newChannel.id,
      openSession: () => _sessionFactory(newChannel),
    );
    _scheduleTwoPaneMix();
    return switch (result) {
      AiroMultiviewAddResult.added => MultiviewToggleResult.added,
      AiroMultiviewAddResult.capacityReached =>
        MultiviewToggleResult.capacityReached,
      AiroMultiviewAddResult.alreadyPresent ||
      AiroMultiviewAddResult.openFailed => MultiviewToggleResult.failed,
    };
  }

  Future<void> promote(String channelId) async {
    final twoPane = _isTwoPane;
    await _pool.promote(channelId, routeAudio: !twoPane);
    if (twoPane) {
      await _applyTwoPaneMix(
        state.splitRatio.firstFraction,
        extent: _lastSplitExtent,
      );
    }
  }

  /// Silences every active tile — see [AiroMultiviewPool.muteAll].
  Future<void> muteAll() async {
    _invalidateTwoPaneMix();
    await _pool.muteAll();
  }

  void swap(String firstChannelId, String secondChannelId) {
    _pool.swap(firstChannelId, secondChannelId);
    if (_isTwoPane) {
      unawaited(
        _applyTwoPaneMix(
          state.splitRatio.firstFraction,
          extent: _lastSplitExtent,
        ),
      );
    }
  }

  void setLayout(MultiviewLayoutKind layout) {
    if (_disposed) return;
    final wasTwoPane = _isTwoPane;
    state = MultiviewState(
      sessions: state.sessions,
      featuredChannelId: state.featuredChannelId,
      capacity: state.capacity,
      layout: layout,
      splitRatio: _splitRatioFor(
        preferred: layout,
        sessionCount: state.sessions.length,
        current: state.splitRatio,
      ),
    );
    if (_isTwoPane) {
      _scheduleTwoPaneMix();
    } else if (wasTwoPane) {
      _invalidateTwoPaneMix();
      unawaited(_restoreExclusiveFeaturedAudio());
    }
  }

  void setSplitRatio(MultiviewSplitRatio ratio) {
    if (_disposed) return;
    if (!_isTwoPane) return;
    state = MultiviewState(
      sessions: state.sessions,
      featuredChannelId: state.featuredChannelId,
      capacity: state.capacity,
      layout: state.layout,
      splitRatio: ratio,
    );
    unawaited(_applyTwoPaneMix(ratio.firstFraction, extent: _lastSplitExtent));
  }

  /// Live equal-power mix for a dragged split fraction.
  Future<void> previewSplitMix(
    double firstFraction, {
    required double extent,
  }) async {
    if (_disposed || !_isTwoPane) return;
    _lastSplitExtent = extent;
    await _applyTwoPaneMix(firstFraction, extent: extent);
  }

  MultiviewSplitRatio _splitRatioFor({
    required MultiviewLayoutKind? preferred,
    required int sessionCount,
    required MultiviewSplitRatio current,
  }) {
    final kind = resolveMultiviewLayout(
      preferred: preferred,
      sessionCount: sessionCount,
    );
    return kind.isTwoPane ? current : MultiviewSplitRatio.fifty;
  }

  Future<void> close() async {
    if (_disposed) return;
    _disposed = true;
    _mixGeneration++;
    await _pool.close();
    await _resumePrimary();
  }

  bool get _isTwoPane => resolveMultiviewLayout(
    preferred: state.layout,
    sessionCount: state.sessions.length,
  ).isTwoPane;

  bool _stillTwoPanePair(
    IptvMultiviewSession first,
    IptvMultiviewSession second,
    int generation,
  ) {
    return !_disposed &&
        generation == _mixGeneration &&
        state.sessions.length == 2 &&
        identical(state.sessions[0], first) &&
        identical(state.sessions[1], second);
  }

  Future<void> _applyTwoPaneMix(
    double firstFraction, {
    required double extent,
  }) async {
    final generation = ++_mixGeneration;
    if (_disposed || state.sessions.length != 2) return;
    final first = state.sessions[0];
    final second = state.sessions[1];
    final gains = multiviewSplitGains(
      firstFraction,
      extent: extent,
      globalVolume: _primaryVolumeHeldForMultiview,
    );
    if (!_stillTwoPanePair(first, second, generation)) return;
    await first.setVolume(gains.first);
    if (!_stillTwoPanePair(first, second, generation)) return;
    await second.setVolume(gains.second);
  }

  void _invalidateTwoPaneMix() {
    _mixGeneration++;
  }

  void _scheduleTwoPaneMix() {
    if (_disposed || !_isTwoPane) return;
    unawaited(
      _applyTwoPaneMix(
        state.splitRatio.firstFraction,
        extent: _lastSplitExtent,
      ),
    );
  }

  Future<void> _restoreExclusiveFeaturedAudio() async {
    final generation = _mixGeneration;
    final featuredId = state.featuredChannelId;
    for (final session in List<IptvMultiviewSession>.of(state.sessions)) {
      if (_disposed || _isTwoPane || generation != _mixGeneration) return;
      await session.setVolume(session.id == featuredId ? 1 : 0);
    }
  }

  void _syncFromPool(AiroMultiviewPoolState poolState) {
    if (_disposed) return;
    final wasTwoPane = _isTwoPane;
    state = MultiviewState(
      sessions: List.unmodifiable(
        poolState.sessions.cast<IptvMultiviewSession>(),
      ),
      featuredChannelId: poolState.featuredSessionId,
      capacity: _pool.capacity,
      layout: state.layout,
      splitRatio: _splitRatioFor(
        preferred: state.layout,
        sessionCount: poolState.sessions.length,
        current: state.splitRatio,
      ),
    );
    if (_isTwoPane) {
      if (poolState.featuredSessionId == null) {
        _invalidateTwoPaneMix();
        return;
      }
      _scheduleTwoPaneMix();
    } else if (wasTwoPane) {
      _invalidateTwoPaneMix();
    }
  }

  Future<void> _holdPrimaryForMultiview() async {
    if (_primaryHeldByMultiview) return;
    final state = _primaryService.currentState;
    final hasActivePipeline =
        state.currentChannel != null ||
        state.isPlaying ||
        state.isLoading ||
        state.isBuffering;
    if (!hasActivePipeline) return;

    _primaryHeldByMultiview = true;
    _primaryChannelHeldForMultiview = state.currentChannel;
    _primaryVolumeHeldForMultiview = state.isMuted ? 0 : state.volume;
    try {
      await _primaryService.setVolume(0);
    } catch (_) {
      // Mute is best-effort; pause/stop below still take the decoder.
    }
    await _primaryService.pause();
  }

  /// Drop the original Watch ExoPlayer once a tile owns the picture.
  /// Leaving it paused on Pixel 9 keeps a third decoder (and its audio)
  /// alive under the split-view tiles.
  Future<void> _releasePrimaryDecoder() async {
    if (!_primaryHeldByMultiview) return;
    await _primaryService.stop();
  }

  Future<void> _resumePrimary() async {
    if (!_primaryHeldByMultiview) return;
    _primaryHeldByMultiview = false;
    final channel = _primaryChannelHeldForMultiview;
    final volume = _primaryVolumeHeldForMultiview;
    _primaryChannelHeldForMultiview = null;
    if (channel != null) {
      await _primaryService.playChannel(channel);
    } else {
      await _primaryService.resume();
    }
    try {
      await _primaryService.setVolume(volume);
    } catch (_) {}
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
        // mixWithOthers: true — this instance shares the device with the
        // pool's other tiles and possibly the primary player. Without it,
        // the platform's own exclusive audio-focus handling silently
        // pauses (freezes) whichever instance loses that fight, and no
        // amount of promoting it via setVolume() afterward recovers it —
        // see VideoPlayerStreamingService's `_mixWithOthers` doc comment.
        final service = VideoPlayerStreamingService(
          config: StreamingConfig.live,
          mixWithOthers: true,
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
  Future<void> setVolume(double volume) async {
    try {
      await _service.setVolume(volume.clamp(0.0, 1.0));
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
