import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'media_mode.dart';

/// Category for content filtering
class MediaCategory extends Equatable {
  /// Unique identifier for the category
  final String id;

  /// Display label for the category
  final String label;

  /// Optional icon for the category
  final IconData? icon;

  /// Which mode this category belongs to
  final MediaMode mode;

  const MediaCategory({
    required this.id,
    required this.label,
    this.icon,
    required this.mode,
  });

  @override
  List<Object?> get props => [id, mode];
}

/// Predefined categories for TV and Music modes
class MediaCategories {
  MediaCategories._();

  // TV Categories
  static const tvLive = MediaCategory(
    id: 'tv_live',
    label: 'Live',
    icon: Icons.live_tv,
    mode: MediaMode.tv,
  );

  static const tvMovies = MediaCategory(
    id: 'tv_movies',
    label: 'Movies',
    icon: Icons.movie,
    mode: MediaMode.tv,
  );

  static const tvKids = MediaCategory(
    id: 'tv_kids',
    label: 'Kids',
    icon: Icons.child_care,
    mode: MediaMode.tv,
  );

  static const tvMusic = MediaCategory(
    id: 'tv_music',
    label: 'Music',
    icon: Icons.music_video,
    mode: MediaMode.tv,
  );

  static const tvRegional = MediaCategory(
    id: 'tv_regional',
    label: 'Regional',
    icon: Icons.language,
    mode: MediaMode.tv,
  );

  static const tvNews = MediaCategory(
    id: 'tv_news',
    label: 'News',
    icon: Icons.newspaper,
    mode: MediaMode.tv,
  );

  // Music Categories
  static const musicTrending = MediaCategory(
    id: 'music_trending',
    label: 'Trending',
    icon: Icons.trending_up,
    mode: MediaMode.music,
  );

  static const musicRegional = MediaCategory(
    id: 'music_regional',
    label: 'Regional',
    icon: Icons.language,
    mode: MediaMode.music,
  );

  static const musicIndie = MediaCategory(
    id: 'music_indie',
    label: 'Indie',
    icon: Icons.album,
    mode: MediaMode.music,
  );

  static const musicDevotional = MediaCategory(
    id: 'music_devotional',
    label: 'Devotional',
    icon: Icons.self_improvement,
    mode: MediaMode.music,
  );

  static const musicChill = MediaCategory(
    id: 'music_chill',
    label: 'Chill',
    icon: Icons.spa,
    mode: MediaMode.music,
  );

  static const musicFocus = MediaCategory(
    id: 'music_focus',
    label: 'Focus',
    icon: Icons.psychology,
    mode: MediaMode.music,
  );

  /// Get all TV categories
  static List<MediaCategory> get tvCategories => [
    tvLive,
    tvMovies,
    tvKids,
    tvMusic,
    tvRegional,
    tvNews,
  ];

  /// Get all Music categories
  static List<MediaCategory> get musicCategories => [
    musicTrending,
    musicRegional,
    musicIndie,
    musicDevotional,
    musicChill,
    musicFocus,
  ];

  /// Get categories for a specific mode
  static List<MediaCategory> forMode(MediaMode mode) =>
      mode == MediaMode.tv ? tvCategories : musicCategories;

  /// Find category by ID
  static MediaCategory? findById(String id) {
    final all = [...tvCategories, ...musicCategories];
    try {
      return all.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }
}
