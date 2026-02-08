import 'package:equatable/equatable.dart';

/// Source type for a Beats track
enum BeatsSource { youtube, soundcloud, local, unknown }

/// Resolved track from Beats search/URL resolution
class BeatsTrack extends Equatable {
  final String id;
  final String title;
  final String artist;
  final String? thumbnailUrl;
  final Duration duration;
  final BeatsSource source;
  final String? sourceUrl; // Original YouTube/SoundCloud URL
  final String? streamUrl; // HLS stream URL (resolved by backend)
  final DateTime? resolvedAt;

  const BeatsTrack({
    required this.id,
    required this.title,
    required this.artist,
    this.thumbnailUrl,
    required this.duration,
    required this.source,
    this.sourceUrl,
    this.streamUrl,
    this.resolvedAt,
  });

  /// Check if track is ready to play (has stream URL)
  bool get isPlayable => streamUrl != null && streamUrl!.isNotEmpty;

  /// Get source icon name
  String get sourceIcon {
    switch (source) {
      case BeatsSource.youtube:
        return 'youtube';
      case BeatsSource.soundcloud:
        return 'soundcloud';
      case BeatsSource.local:
        return 'music_note';
      case BeatsSource.unknown:
        return 'music_note';
    }
  }

  /// Get formatted duration string (MM:SS)
  String get durationFormatted {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  List<Object?> get props => [
    id,
    title,
    artist,
    thumbnailUrl,
    duration,
    source,
    sourceUrl,
    streamUrl,
    resolvedAt,
  ];

  /// Create a copy with updated fields
  BeatsTrack copyWith({
    String? id,
    String? title,
    String? artist,
    String? thumbnailUrl,
    Duration? duration,
    BeatsSource? source,
    String? sourceUrl,
    String? streamUrl,
    DateTime? resolvedAt,
  }) {
    return BeatsTrack(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      duration: duration ?? this.duration,
      source: source ?? this.source,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      streamUrl: streamUrl ?? this.streamUrl,
      resolvedAt: resolvedAt ?? this.resolvedAt,
    );
  }
}

/// Search result from Beats API
class BeatsSearchResult extends Equatable {
  final List<BeatsTrack> tracks;
  final String query;
  final int totalResults;
  final bool hasMore;
  final String? nextPageToken;

  const BeatsSearchResult({
    required this.tracks,
    required this.query,
    this.totalResults = 0,
    this.hasMore = false,
    this.nextPageToken,
  });

  @override
  List<Object?> get props => [
    tracks,
    query,
    totalResults,
    hasMore,
    nextPageToken,
  ];
}

/// Stream session for a track
class BeatsStreamSession extends Equatable {
  final String sessionId;
  final String trackId;
  final String hlsManifestUrl;
  final DateTime createdAt;
  final DateTime expiresAt;

  const BeatsStreamSession({
    required this.sessionId,
    required this.trackId,
    required this.hlsManifestUrl,
    required this.createdAt,
    required this.expiresAt,
  });

  /// Check if session is expired
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Time remaining until expiration
  Duration get timeRemaining => expiresAt.difference(DateTime.now());

  @override
  List<Object?> get props => [
    sessionId,
    trackId,
    hlsManifestUrl,
    createdAt,
    expiresAt,
  ];
}

/// Search state for UI
enum BeatsSearchState { idle, searching, resolving, success, error }

/// Beats search UI state
class BeatsSearchUiState extends Equatable {
  final BeatsSearchState state;
  final String query;
  final List<BeatsTrack> results;
  final String? errorMessage;
  final BeatsTrack? resolvingTrack;

  const BeatsSearchUiState({
    this.state = BeatsSearchState.idle,
    this.query = '',
    this.results = const [],
    this.errorMessage,
    this.resolvingTrack,
  });

  @override
  List<Object?> get props => [
    state,
    query,
    results,
    errorMessage,
    resolvingTrack,
  ];

  BeatsSearchUiState copyWith({
    BeatsSearchState? state,
    String? query,
    List<BeatsTrack>? results,
    String? errorMessage,
    BeatsTrack? resolvingTrack,
  }) {
    return BeatsSearchUiState(
      state: state ?? this.state,
      query: query ?? this.query,
      results: results ?? this.results,
      errorMessage: errorMessage ?? this.errorMessage,
      resolvingTrack: resolvingTrack ?? this.resolvingTrack,
    );
  }
}
