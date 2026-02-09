import 'package:equatable/equatable.dart';
import 'unified_media_content.dart';

/// User personalization state for resume/favorites
class PersonalizationState extends Equatable {
  /// Content that can be resumed (partially watched/listened)
  final List<UnifiedMediaContent> continueWatching;

  /// Recently played content
  final List<UnifiedMediaContent> recentlyPlayed;

  /// Set of favorited content IDs
  final Set<String> favoriteIds;

  /// Map of content ID to last playback position
  final Map<String, Duration> playbackPositions;

  /// Maximum items to keep in recently played
  static const int maxRecentItems = 50;

  /// Maximum items to show in continue watching
  static const int maxContinueItems = 20;

  const PersonalizationState({
    this.continueWatching = const [],
    this.recentlyPlayed = const [],
    this.favoriteIds = const {},
    this.playbackPositions = const {},
  });

  /// Check if content is favorited
  bool isFavorite(String contentId) => favoriteIds.contains(contentId);

  /// Get last position for content
  Duration? getLastPosition(String contentId) => playbackPositions[contentId];

  /// Check if content can be resumed
  bool canResume(String contentId) {
    final position = playbackPositions[contentId];
    return position != null && position.inSeconds > 10;
  }

  /// Get progress for content (0.0 - 1.0)
  double getProgress(String contentId, Duration? totalDuration) {
    final position = playbackPositions[contentId];
    if (position == null || totalDuration == null) return 0.0;
    if (totalDuration.inMilliseconds == 0) return 0.0;
    return (position.inMilliseconds / totalDuration.inMilliseconds).clamp(
      0.0,
      1.0,
    );
  }

  /// Get count of favorites
  int get favoritesCount => favoriteIds.length;

  /// Get count of continue watching items
  int get continueWatchingCount => continueWatching.length;

  PersonalizationState copyWith({
    List<UnifiedMediaContent>? continueWatching,
    List<UnifiedMediaContent>? recentlyPlayed,
    Set<String>? favoriteIds,
    Map<String, Duration>? playbackPositions,
  }) {
    return PersonalizationState(
      continueWatching: continueWatching ?? this.continueWatching,
      recentlyPlayed: recentlyPlayed ?? this.recentlyPlayed,
      favoriteIds: favoriteIds ?? this.favoriteIds,
      playbackPositions: playbackPositions ?? this.playbackPositions,
    );
  }

  /// Create from JSON (for persistence)
  factory PersonalizationState.fromJson(Map<String, dynamic> json) {
    return PersonalizationState(
      favoriteIds: Set<String>.from(json['favoriteIds'] as List? ?? []),
      playbackPositions:
          (json['playbackPositions'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, Duration(milliseconds: v as int)),
          ) ??
          {},
    );
  }

  /// Convert to JSON (for persistence)
  /// Note: continueWatching and recentlyPlayed are derived, not persisted directly
  Map<String, dynamic> toJson() {
    return {
      'favoriteIds': favoriteIds.toList(),
      'playbackPositions': playbackPositions.map(
        (k, v) => MapEntry(k, v.inMilliseconds),
      ),
    };
  }

  @override
  List<Object?> get props => [
    continueWatching,
    recentlyPlayed,
    favoriteIds,
    playbackPositions,
  ];
}
