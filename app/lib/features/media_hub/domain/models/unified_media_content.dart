import 'package:equatable/equatable.dart';
import '../../../iptv/domain/models/iptv_channel.dart';
import '../../../music/domain/services/music_service.dart';
import 'media_category.dart';
import 'media_mode.dart';

/// Unified content model for both music and TV
class UnifiedMediaContent extends Equatable {
  /// Unique identifier
  final String id;

  /// Content title
  final String title;

  /// Subtitle (Artist for music, group for TV)
  final String? subtitle;

  /// Thumbnail/cover image URL
  final String? thumbnailUrl;

  /// Stream URL for playback
  final String? streamUrl;

  /// Content type (Music or TV)
  final MediaMode type;

  /// Category for filtering
  final MediaCategory? category;

  /// Duration (null for live content)
  final Duration? duration;

  /// Whether this is live content
  final bool isLive;

  /// Current viewer count (for live TV)
  final int? viewerCount;

  /// Tags for search/filtering
  final List<String> tags;

  /// Last time this content was played
  final DateTime? lastPlayed;

  /// Last playback position (for resume)
  final Duration? lastPosition;

  const UnifiedMediaContent({
    required this.id,
    required this.title,
    this.subtitle,
    this.thumbnailUrl,
    this.streamUrl,
    required this.type,
    this.category,
    this.duration,
    this.isLive = false,
    this.viewerCount,
    this.tags = const [],
    this.lastPlayed,
    this.lastPosition,
  });

  /// Check if content can be resumed (played > 10 seconds)
  bool get canResume =>
      lastPosition != null && lastPosition!.inSeconds > 10;

  /// Check if this is music content
  bool get isMusic => type == MediaMode.music;

  /// Check if this is TV content
  bool get isTV => type == MediaMode.tv;

  /// Get progress percentage (0.0 - 1.0)
  double get progress {
    if (duration == null || lastPosition == null) return 0.0;
    if (duration!.inMilliseconds == 0) return 0.0;
    return (lastPosition!.inMilliseconds / duration!.inMilliseconds)
        .clamp(0.0, 1.0);
  }

  /// Convert from IPTVChannel
  factory UnifiedMediaContent.fromChannel(IPTVChannel channel) {
    return UnifiedMediaContent(
      id: 'tv_${channel.id}',
      title: channel.name,
      subtitle: channel.group,
      thumbnailUrl: channel.logoUrl,
      streamUrl: channel.streamUrl,
      type: MediaMode.tv,
      category: _mapChannelCategory(channel.category),
      isLive: true,
      tags: [channel.category.label, ...channel.languages],
    );
  }

  /// Convert from MusicTrack
  factory UnifiedMediaContent.fromTrack(MusicTrack track) {
    return UnifiedMediaContent(
      id: 'music_${track.id}',
      title: track.title,
      subtitle: track.artist,
      thumbnailUrl: track.albumArt,
      streamUrl: track.streamUrl,
      type: MediaMode.music,
      duration: track.duration,
      isLive: false,
    );
  }

  /// Map IPTV channel category to MediaCategory
  static MediaCategory? _mapChannelCategory(ChannelCategory category) {
    switch (category) {
      case ChannelCategory.news:
        return MediaCategories.tvNews;
      case ChannelCategory.movies:
        return MediaCategories.tvMovies;
      case ChannelCategory.kids:
        return MediaCategories.tvKids;
      case ChannelCategory.music:
        return MediaCategories.tvMusic;
      case ChannelCategory.regional:
        return MediaCategories.tvRegional;
      default:
        return MediaCategories.tvLive;
    }
  }

  UnifiedMediaContent copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? thumbnailUrl,
    String? streamUrl,
    MediaMode? type,
    MediaCategory? category,
    Duration? duration,
    bool? isLive,
    int? viewerCount,
    List<String>? tags,
    DateTime? lastPlayed,
    Duration? lastPosition,
  }) {
    return UnifiedMediaContent(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      streamUrl: streamUrl ?? this.streamUrl,
      type: type ?? this.type,
      category: category ?? this.category,
      duration: duration ?? this.duration,
      isLive: isLive ?? this.isLive,
      viewerCount: viewerCount ?? this.viewerCount,
      tags: tags ?? this.tags,
      lastPlayed: lastPlayed ?? this.lastPlayed,
      lastPosition: lastPosition ?? this.lastPosition,
    );
  }

  @override
  List<Object?> get props => [id, type];
}

