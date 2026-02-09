import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../iptv/application/providers/iptv_providers.dart';
import '../../domain/models/personalization_state.dart';
import '../../domain/models/unified_media_content.dart';

/// Personalization state notifier for favorites, history, and resume
class PersonalizationNotifier extends StateNotifier<PersonalizationState> {
  final Ref _ref;
  static const String _storageKey = 'media_hub_personalization';

  PersonalizationNotifier(this._ref) : super(const PersonalizationState()) {
    _loadFromStorage();
  }

  /// Add content to recently played
  void addToRecent(UnifiedMediaContent content) {
    final updated = [
      content,
      ...state.recentlyPlayed.where((c) => c.id != content.id),
    ].take(PersonalizationState.maxRecentItems).toList();
    state = state.copyWith(recentlyPlayed: updated);
    _saveToStorage();
  }

  /// Save playback position for resume
  void savePosition(String contentId, Duration position) {
    final positions = Map<String, Duration>.from(state.playbackPositions);
    positions[contentId] = position;
    state = state.copyWith(playbackPositions: positions);

    // Update continue watching list
    _updateContinueWatching();
    _saveToStorage();
  }

  /// Clear position (when content finishes)
  void clearPosition(String contentId) {
    final positions = Map<String, Duration>.from(state.playbackPositions);
    positions.remove(contentId);
    state = state.copyWith(playbackPositions: positions);
    _updateContinueWatching();
    _saveToStorage();
  }

  /// Toggle favorite status
  void toggleFavorite(String contentId) {
    final favorites = Set<String>.from(state.favoriteIds);
    if (favorites.contains(contentId)) {
      favorites.remove(contentId);
    } else {
      favorites.add(contentId);
    }
    state = state.copyWith(favoriteIds: favorites);
    _saveToStorage();
  }

  /// Add to favorites
  void addFavorite(String contentId) {
    if (state.favoriteIds.contains(contentId)) return;
    final favorites = Set<String>.from(state.favoriteIds)..add(contentId);
    state = state.copyWith(favoriteIds: favorites);
    _saveToStorage();
  }

  /// Remove from favorites
  void removeFavorite(String contentId) {
    if (!state.favoriteIds.contains(contentId)) return;
    final favorites = Set<String>.from(state.favoriteIds)..remove(contentId);
    state = state.copyWith(favoriteIds: favorites);
    _saveToStorage();
  }

  void _updateContinueWatching() {
    // Filter recently played to those with valid resume positions (>10 seconds)
    final continueList = state.recentlyPlayed
        .where((content) {
          final position = state.playbackPositions[content.id];
          return position != null && position.inSeconds > 10;
        })
        .take(PersonalizationState.maxContinueItems)
        .toList();

    state = state.copyWith(continueWatching: continueList);
  }

  Future<void> _loadFromStorage() async {
    try {
      final prefs = _ref.read(sharedPreferencesProvider);
      final jsonString = prefs.getString(_storageKey);
      if (jsonString != null) {
        final json = jsonDecode(jsonString) as Map<String, dynamic>;
        state = PersonalizationState.fromJson(json);
      }
    } catch (e) {
      // Failed to load, keep default state
    }
  }

  Future<void> _saveToStorage() async {
    try {
      final prefs = _ref.read(sharedPreferencesProvider);
      final jsonString = jsonEncode(state.toJson());
      await prefs.setString(_storageKey, jsonString);
    } catch (e) {
      // Failed to save
    }
  }

  /// Clear all personalization data
  Future<void> clearAll() async {
    state = const PersonalizationState();
    try {
      final prefs = _ref.read(sharedPreferencesProvider);
      await prefs.remove(_storageKey);
    } catch (e) {
      // Ignore
    }
  }
}

/// Personalization provider
final personalizationProvider =
    StateNotifierProvider<PersonalizationNotifier, PersonalizationState>(
      (ref) => PersonalizationNotifier(ref),
    );

/// Derived: Continue watching content
final continueWatchingProvider = Provider<List<UnifiedMediaContent>>((ref) {
  return ref.watch(personalizationProvider).continueWatching;
});

/// Derived: Recently played content
final recentlyPlayedProvider = Provider<List<UnifiedMediaContent>>((ref) {
  return ref.watch(personalizationProvider).recentlyPlayed;
});

/// Derived: Check if content is favorited
final isFavoriteProvider = Provider.family<bool, String>((ref, contentId) {
  return ref.watch(personalizationProvider).isFavorite(contentId);
});
