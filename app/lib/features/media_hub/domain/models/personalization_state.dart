import 'dart:convert';

import 'package:equatable/equatable.dart';

import 'unified_media_content.dart';

class PersonalizationState extends Equatable {
  const PersonalizationState({
    this.favorites = const [],
    this.recentlyPlayed = const [],
    this.continueWatching = const [],
  });

  static const maxFavorites = 50;
  static const maxRecentlyPlayed = 20;
  static const maxContinueWatching = 20;

  final List<UnifiedMediaContent> favorites;
  final List<UnifiedMediaContent> recentlyPlayed;
  final List<UnifiedMediaContent> continueWatching;

  PersonalizationState copyWith({
    List<UnifiedMediaContent>? favorites,
    List<UnifiedMediaContent>? recentlyPlayed,
    List<UnifiedMediaContent>? continueWatching,
  }) {
    return PersonalizationState(
      favorites: favorites ?? this.favorites,
      recentlyPlayed: recentlyPlayed ?? this.recentlyPlayed,
      continueWatching: continueWatching ?? this.continueWatching,
    );
  }

  bool isFavorite(String contentId) {
    return favorites.any((item) => item.id == contentId);
  }

  Map<String, dynamic> toJson() {
    return {
      'favorites': favorites.map((item) => item.toJson()).toList(),
      'recentlyPlayed': recentlyPlayed.map((item) => item.toJson()).toList(),
      'continueWatching': continueWatching
          .map((item) => item.toJson())
          .toList(),
    };
  }

  String toStorageValue() => jsonEncode(toJson());

  factory PersonalizationState.fromJson(Map<String, dynamic> json) {
    List<UnifiedMediaContent> readList(String key) {
      final raw = json[key] as List<dynamic>? ?? const [];
      return List<UnifiedMediaContent>.unmodifiable(
        raw
            .map(
              (item) =>
                  UnifiedMediaContent.fromJson(item as Map<String, dynamic>),
            )
            .toList(),
      );
    }

    return PersonalizationState(
      favorites: readList('favorites'),
      recentlyPlayed: readList('recentlyPlayed'),
      continueWatching: readList('continueWatching'),
    );
  }

  factory PersonalizationState.fromStorageValue(String raw) {
    return PersonalizationState.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
  }

  @override
  List<Object?> get props => [favorites, recentlyPlayed, continueWatching];
}
