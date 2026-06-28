import 'package:equatable/equatable.dart';

import '../../../iptv/domain/models/iptv_channel.dart';
import '../../../music/domain/services/music_service.dart';
import 'media_category.dart';
import 'media_mode.dart';

class UnifiedMediaContent extends Equatable {
  const UnifiedMediaContent({
    required this.id,
    required this.mode,
    required this.category,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.streamUrl,
    this.duration = Duration.zero,
    this.lastPosition = Duration.zero,
    this.isLive = false,
    this.viewerCount,
    this.tags = const [],
  });

  factory UnifiedMediaContent.fromTrack(
    MusicTrack track, {
    Duration lastPosition = Duration.zero,
    List<String> tags = const [],
  }) {
    return UnifiedMediaContent(
      id: track.id,
      mode: MediaMode.music,
      category: MediaCategory.music,
      title: track.title,
      subtitle: track.artist,
      imageUrl: track.albumArt,
      streamUrl: track.streamUrl,
      duration: track.duration,
      lastPosition: lastPosition,
      tags: tags,
    );
  }

  factory UnifiedMediaContent.fromChannel(
    IPTVChannel channel, {
    Duration lastPosition = Duration.zero,
    int? viewerCount,
    List<String> tags = const [],
  }) {
    return UnifiedMediaContent(
      id: channel.id,
      mode: MediaMode.tv,
      category: MediaCategoryX.fromChannelCategory(channel.category),
      title: channel.name,
      subtitle: channel.group,
      imageUrl: channel.logoUrl,
      streamUrl: channel.streamUrl,
      lastPosition: lastPosition,
      isLive: !channel.isAudioOnly,
      viewerCount: viewerCount,
      tags: tags.isEmpty ? channel.languages : tags,
    );
  }

  final String id;
  final MediaMode mode;
  final MediaCategory category;
  final String title;
  final String subtitle;
  final String? imageUrl;
  final String? streamUrl;
  final Duration duration;
  final Duration lastPosition;
  final bool isLive;
  final int? viewerCount;
  final List<String> tags;

  bool get canResume =>
      !isLive &&
      lastPosition > Duration.zero &&
      duration > Duration.zero &&
      lastPosition < duration;

  @override
  List<Object?> get props => [
    id,
    mode,
    category,
    title,
    subtitle,
    imageUrl,
    streamUrl,
    duration,
    lastPosition,
    isLive,
    viewerCount,
    tags,
  ];
}
