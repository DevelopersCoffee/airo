import 'package:equatable/equatable.dart';

import 'streaming_state.dart';

/// Renderer-agnostic snapshot of everything the player overlay needs to
/// render itself. The overlay widget must depend ONLY on this aggregate —
/// never on ExoPlayer/VLC/engine-specific types — so it can sit in front of
/// any [AiroPlaybackBackendKind] without change.
///
/// Named `PlayerViewState` (not `PlayerState`) per the Task 8 brief to avoid
/// any future collision with an engine-side `PlayerState` type; a grep of
/// this package found no existing `PlayerState` symbol, but the brief's file
/// names, test file, and commit message were already fixed to
/// `PlayerViewState`, so that name was kept for consistency.
class PlayerViewState extends Equatable {
  const PlayerViewState({
    this.playback = PlaybackState.idle,
    this.liveState = LiveStreamState.unknown,
    this.networkQuality = NetworkQuality.good,
    this.bufferSeconds = 0,
    this.qualityLabel = 'Auto',
    this.title = '',
    this.subtitle = '',
    this.failover,
  });

  final PlaybackState playback;
  final LiveStreamState liveState;
  final NetworkQuality networkQuality;
  final int bufferSeconds;
  final String qualityLabel;
  final String title;
  final String subtitle;

  /// Non-null while a source switch is in flight → drives the failover toast.
  final FailoverProgress? failover;

  PlayerViewState copyWith({
    PlaybackState? playback,
    LiveStreamState? liveState,
    NetworkQuality? networkQuality,
    int? bufferSeconds,
    String? qualityLabel,
    String? title,
    String? subtitle,
    FailoverProgress? failover,
    bool clearFailover = false,
  }) {
    return PlayerViewState(
      playback: playback ?? this.playback,
      liveState: liveState ?? this.liveState,
      networkQuality: networkQuality ?? this.networkQuality,
      bufferSeconds: bufferSeconds ?? this.bufferSeconds,
      qualityLabel: qualityLabel ?? this.qualityLabel,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      failover: clearFailover ? null : (failover ?? this.failover),
    );
  }

  @override
  List<Object?> get props => [
    playback,
    liveState,
    networkQuality,
    bufferSeconds,
    qualityLabel,
    title,
    subtitle,
    failover,
  ];
}

/// Progress marker for an in-flight multi-source failover switch, surfaced
/// by the overlay as a toast (e.g. "Switching source 2/4").
class FailoverProgress extends Equatable {
  const FailoverProgress({required this.currentSource, required this.totalSources});

  /// 1-based index of the source currently being attempted.
  final int currentSource;
  final int totalSources;

  @override
  List<Object?> get props => [currentSource, totalSources];
}
