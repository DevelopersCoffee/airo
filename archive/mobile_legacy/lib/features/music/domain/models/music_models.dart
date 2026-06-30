import 'package:equatable/equatable.dart';

/// Audio item model
class AudioItem extends Equatable {
  final String id;
  final String title;
  final String artist;
  final String? album;
  final String? albumArt;
  final Duration duration;
  final String? url;
  final DateTime? addedAt;

  const AudioItem({
    required this.id,
    required this.title,
    required this.artist,
    this.album,
    this.albumArt,
    required this.duration,
    this.url,
    this.addedAt,
  });

  /// Get duration as formatted string (MM:SS)
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
    album,
    albumArt,
    duration,
    url,
    addedAt,
  ];
}

/// Playlist model
class Playlist extends Equatable {
  final String id;
  final String name;
  final String? description;
  final String? coverArt;
  final List<AudioItem> items;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Playlist({
    required this.id,
    required this.name,
    this.description,
    this.coverArt,
    this.items = const [],
    required this.createdAt,
    this.updatedAt,
  });

  /// Get total duration of playlist
  Duration get totalDuration {
    return items.fold(Duration.zero, (prev, item) => prev + item.duration);
  }

  /// Get total duration as formatted string
  String get totalDurationFormatted {
    final minutes = totalDuration.inMinutes;
    final seconds = totalDuration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  List<Object?> get props => [
    id,
    name,
    description,
    coverArt,
    items,
    createdAt,
    updatedAt,
  ];
}

/// Audio queue model
class AudioQueue extends Equatable {
  final List<AudioItem> items;
  final int currentIndex;
  final bool isPlaying;
  final Duration currentPosition;

  const AudioQueue({
    this.items = const [],
    this.currentIndex = 0,
    this.isPlaying = false,
    this.currentPosition = Duration.zero,
  });

  /// Get current item
  AudioItem? get currentItem => currentIndex >= 0 && currentIndex < items.length
      ? items[currentIndex]
      : null;

  /// Get next item
  AudioItem? get nextItem =>
      (currentIndex + 1) < items.length ? items[currentIndex + 1] : null;

  /// Get previous item
  AudioItem? get previousItem =>
      currentIndex > 0 ? items[currentIndex - 1] : null;

  /// Check if has next item
  bool get hasNext => (currentIndex + 1) < items.length;

  /// Check if has previous item
  bool get hasPrevious => currentIndex > 0;

  @override
  List<Object?> get props => [items, currentIndex, isPlaying, currentPosition];
}

/// Audio player state
enum AudioPlayerState { idle, loading, playing, paused, stopped, error }

/// Audio player model
class AudioPlayerStatus extends Equatable {
  final AudioPlayerState state;
  final AudioItem? currentItem;
  final Duration currentPosition;
  final Duration? duration;
  final double volume;
  final bool isMuted;
  final String? error;

  const AudioPlayerStatus({
    required this.state,
    this.currentItem,
    this.currentPosition = Duration.zero,
    this.duration,
    this.volume = 1.0,
    this.isMuted = false,
    this.error,
  });

  @override
  List<Object?> get props => [
    state,
    currentItem,
    currentPosition,
    duration,
    volume,
    isMuted,
    error,
  ];
}
