import 'package:equatable/equatable.dart';
import 'beats_models.dart';

/// Repeat mode for queue playback
enum BeatsRepeatMode { off, one, all }

/// Enhanced queue state with persistence support
class BeatsQueueState extends Equatable {
  /// List of tracks in the queue
  final List<BeatsTrack> tracks;

  /// Current playing track index (-1 if empty)
  final int currentIndex;

  /// Current playback position
  final Duration position;

  /// Repeat mode
  final BeatsRepeatMode repeatMode;

  /// Whether shuffle is enabled
  final bool shuffleEnabled;

  /// Unique session identifier
  final String sessionId;

  /// Last update timestamp
  final DateTime lastUpdated;

  /// Original track order (before shuffle)
  final List<String>? originalOrder;

  const BeatsQueueState({
    this.tracks = const [],
    this.currentIndex = -1,
    this.position = Duration.zero,
    this.repeatMode = BeatsRepeatMode.off,
    this.shuffleEnabled = false,
    this.sessionId = '',
    required this.lastUpdated,
    this.originalOrder,
  });

  /// Create an empty queue state
  factory BeatsQueueState.empty() =>
      BeatsQueueState(lastUpdated: DateTime.now());

  /// Get current track or null
  BeatsTrack? get currentTrack {
    if (currentIndex >= 0 && currentIndex < tracks.length) {
      return tracks[currentIndex];
    }
    return null;
  }

  /// Check if queue is empty
  bool get isEmpty => tracks.isEmpty;

  /// Check if queue has tracks
  bool get isNotEmpty => tracks.isNotEmpty;

  /// Total number of tracks
  int get length => tracks.length;

  /// Check if can skip to next
  bool get hasNext {
    if (repeatMode == BeatsRepeatMode.all && isNotEmpty) return true;
    return currentIndex < tracks.length - 1;
  }

  /// Check if can skip to previous
  bool get hasPrevious {
    if (repeatMode == BeatsRepeatMode.all && isNotEmpty) return true;
    return currentIndex > 0;
  }

  /// Copy with new values
  BeatsQueueState copyWith({
    List<BeatsTrack>? tracks,
    int? currentIndex,
    Duration? position,
    BeatsRepeatMode? repeatMode,
    bool? shuffleEnabled,
    String? sessionId,
    DateTime? lastUpdated,
    List<String>? originalOrder,
  }) {
    return BeatsQueueState(
      tracks: tracks ?? this.tracks,
      currentIndex: currentIndex ?? this.currentIndex,
      position: position ?? this.position,
      repeatMode: repeatMode ?? this.repeatMode,
      shuffleEnabled: shuffleEnabled ?? this.shuffleEnabled,
      sessionId: sessionId ?? this.sessionId,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      originalOrder: originalOrder ?? this.originalOrder,
    );
  }

  /// Convert to JSON for persistence
  Map<String, dynamic> toJson() {
    return {
      'tracks': tracks.map((t) => t.toJson()).toList(),
      'currentIndex': currentIndex,
      'positionMs': position.inMilliseconds,
      'repeatMode': repeatMode.index,
      'shuffleEnabled': shuffleEnabled,
      'sessionId': sessionId,
      'lastUpdated': lastUpdated.toIso8601String(),
      'originalOrder': originalOrder,
    };
  }

  /// Create from JSON
  factory BeatsQueueState.fromJson(Map<String, dynamic> json) {
    return BeatsQueueState(
      tracks:
          (json['tracks'] as List?)
              ?.map((t) => BeatsTrack.fromJson(t as Map<String, dynamic>))
              .toList() ??
          [],
      currentIndex: json['currentIndex'] as int? ?? -1,
      position: Duration(milliseconds: json['positionMs'] as int? ?? 0),
      repeatMode: BeatsRepeatMode.values[json['repeatMode'] as int? ?? 0],
      shuffleEnabled: json['shuffleEnabled'] as bool? ?? false,
      sessionId: json['sessionId'] as String? ?? '',
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.parse(json['lastUpdated'] as String)
          : DateTime.now(),
      originalOrder: (json['originalOrder'] as List?)?.cast<String>(),
    );
  }

  @override
  List<Object?> get props => [
    tracks,
    currentIndex,
    position,
    repeatMode,
    shuffleEnabled,
    sessionId,
    lastUpdated,
    originalOrder,
  ];
}
