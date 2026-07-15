import 'package:core_data/core_data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:feature_iptv/feature_iptv.dart' show sharedPreferencesProvider;
import '../../domain/models/personalization_state.dart';
import '../../domain/models/unified_media_content.dart';

const mediaHubPersonalizationStorageKey = 'media_hub_personalization_state';

final personalizationProvider =
    AsyncNotifierProvider<PersonalizationNotifier, PersonalizationState>(
      PersonalizationNotifier.new,
    );

final mediaHubPersonalizationStoreProvider = Provider<KeyValueStore>((ref) {
  return PreferencesStore(ref.watch(sharedPreferencesProvider));
});

class PersonalizationNotifier extends AsyncNotifier<PersonalizationState> {
  @override
  Future<PersonalizationState> build() async {
    final store = ref.watch(mediaHubPersonalizationStoreProvider);
    final raw = await store.getString(mediaHubPersonalizationStorageKey);
    if (raw == null || raw.trim().isEmpty) {
      return const PersonalizationState();
    }
    return PersonalizationState.fromStorageValue(raw);
  }

  Future<void> toggleFavorite(UnifiedMediaContent item) async {
    final current = state.valueOrNull ?? await future;
    final nextFavorites = List<UnifiedMediaContent>.from(current.favorites);
    final index = nextFavorites.indexWhere((entry) => entry.id == item.id);
    if (index >= 0) {
      nextFavorites.removeAt(index);
    } else {
      nextFavorites.insert(0, item);
      _trim(nextFavorites, PersonalizationState.maxFavorites);
    }
    await _persist(
      current.copyWith(favorites: List.unmodifiable(nextFavorites)),
    );
  }

  Future<void> addRecent(UnifiedMediaContent item) async {
    final current = state.valueOrNull ?? await future;
    final nextRecent = _upsertAtFront(current.recentlyPlayed, item);
    _trim(nextRecent, PersonalizationState.maxRecentlyPlayed);
    await _persist(
      current.copyWith(recentlyPlayed: List.unmodifiable(nextRecent)),
    );
  }

  Future<void> updateProgress(
    UnifiedMediaContent item,
    Duration position, {
    Duration? duration,
  }) async {
    final current = state.valueOrNull ?? await future;
    final updatedItem = item.copyWith(
      duration: duration ?? item.duration,
      lastPosition: position,
    );
    final nextRecent = _upsertAtFront(current.recentlyPlayed, updatedItem);
    _trim(nextRecent, PersonalizationState.maxRecentlyPlayed);

    final nextContinue = List<UnifiedMediaContent>.from(
      current.continueWatching,
    )..removeWhere((entry) => entry.id == updatedItem.id);
    if (updatedItem.canResume) {
      nextContinue.insert(0, updatedItem);
      _trim(nextContinue, PersonalizationState.maxContinueWatching);
    }

    await _persist(
      current.copyWith(
        recentlyPlayed: List.unmodifiable(nextRecent),
        continueWatching: List.unmodifiable(nextContinue),
      ),
    );
  }

  Future<void> clearAll() async {
    await _persist(const PersonalizationState());
  }

  List<UnifiedMediaContent> _upsertAtFront(
    List<UnifiedMediaContent> current,
    UnifiedMediaContent item,
  ) {
    final next = List<UnifiedMediaContent>.from(current)
      ..removeWhere((entry) => entry.id == item.id)
      ..insert(0, item);
    return next;
  }

  void _trim(List<UnifiedMediaContent> items, int maxLength) {
    while (items.length > maxLength) {
      items.removeLast();
    }
  }

  Future<void> _persist(PersonalizationState next) async {
    final store = ref.read(mediaHubPersonalizationStoreProvider);
    await store.setString(
      mediaHubPersonalizationStorageKey,
      next.toStorageValue(),
    );
    state = AsyncData(next);
  }
}
