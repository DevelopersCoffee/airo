import 'package:equatable/equatable.dart';

/// Source of the audio track
enum BeatsSource { youtube, soundcloud, local, unknown }

/// Represents a track from Beats (YouTube/SoundCloud)
class BeatsTrack extends Equatable {
  final String id;
  final String title;
  final String artist;
  final String? thumbnailUrl;
  final Duration duration;
  final BeatsSource source;
  final String? sourceUrl;
  final String? streamUrl; // HLS stream URL (populated after resolution)

  const BeatsTrack({
    required this.id,
    required this.title,
    required this.artist,
    this.thumbnailUrl,
    this.duration = Duration.zero,
    this.source = BeatsSource.unknown,
    this.sourceUrl,
    this.streamUrl,
  });

  BeatsTrack copyWith({
    String? id,
    String? title,
    String? artist,
    String? thumbnailUrl,
    Duration? duration,
    BeatsSource? source,
    String? sourceUrl,
    String? streamUrl,
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
    );
  }

  /// Convert to JSON for persistence
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'thumbnailUrl': thumbnailUrl,
      'durationMs': duration.inMilliseconds,
      'source': source.index,
      'sourceUrl': sourceUrl,
      'streamUrl': streamUrl,
    };
  }

  /// Create from JSON
  factory BeatsTrack.fromJson(Map<String, dynamic> json) {
    return BeatsTrack(
      id: json['id'] as String,
      title: json['title'] as String,
      artist: json['artist'] as String,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      duration: Duration(milliseconds: json['durationMs'] as int? ?? 0),
      source: BeatsSource.values[json['source'] as int? ?? 3],
      sourceUrl: json['sourceUrl'] as String?,
      streamUrl: json['streamUrl'] as String?,
    );
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
  ];
}

/// Search result containing tracks and pagination info
class BeatsSearchResult extends Equatable {
  final List<BeatsTrack> tracks;
  final String? nextPageToken;
  final int totalResults;

  const BeatsSearchResult({
    required this.tracks,
    this.nextPageToken,
    this.totalResults = 0,
  });

  @override
  List<Object?> get props => [tracks, nextPageToken, totalResults];
}

/// Stream session with HLS manifest URL
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

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Duration get remainingTime => expiresAt.difference(DateTime.now());

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

/// UI state for Beats search
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

  @override
  List<Object?> get props => [
    state,
    query,
    results,
    errorMessage,
    resolvingTrack,
  ];
}

/// Result wrapper for repository operations
class BeatsResult<T> {
  final T? data;
  final String? error;

  const BeatsResult.success(this.data) : error = null;
  const BeatsResult.failure(this.error) : data = null;

  bool get isSuccess => data != null;
  bool get isFailure => error != null;
}
