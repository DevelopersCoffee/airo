import 'dart:convert';

import 'package:core_data/core_data.dart';
import 'package:flutter/foundation.dart';

/// Generic bounded, deduped, most-recent-first list backed by
/// [KeyValueStore] — the storage engine `RecentlyWatchedStorage` already
/// used for live channels, extracted so a second content type (VOD) can
/// reuse the same mechanism under a different [storageKey] without
/// duplicating the add/dedupe/trim/JSON logic.
class BoundedRecentListStore<T> {
  BoundedRecentListStore(
    this._store, {
    required this.storageKey,
    required this.maxSize,
    required this.idOf,
    required this.toJson,
    required this.fromJson,
  });

  final KeyValueStore _store;
  final String storageKey;
  final int maxSize;
  final String Function(T item) idOf;
  final Map<String, dynamic> Function(T item) toJson;
  final T Function(Map<String, dynamic> json) fromJson;

  Future<void> addToRecent(T item) async {
    try {
      final recent = await getRecent();

      recent.removeWhere((existing) => idOf(existing) == idOf(item));
      recent.insert(0, item);

      while (recent.length > maxSize) {
        recent.removeLast();
      }

      await _saveRecent(recent);
    } catch (e) {
      debugPrint('[BoundedRecentListStore:$storageKey] Error adding: $e');
    }
  }

  Future<List<T>> getRecent({int? limit}) async {
    try {
      final json = await _store.getString(storageKey);
      if (json == null) return [];

      final list = jsonDecode(json) as List;
      final items = list
          .map((item) => fromJson(item as Map<String, dynamic>))
          .toList();

      if (limit != null && items.length > limit) {
        return items.take(limit).toList();
      }
      return items;
    } catch (e) {
      debugPrint('[BoundedRecentListStore:$storageKey] Error loading: $e');
      return [];
    }
  }

  Future<void> clearRecent() async {
    await _store.remove(storageKey);
  }

  Future<void> removeFromRecent(String id) async {
    try {
      final recent = await getRecent();
      recent.removeWhere((item) => idOf(item) == id);
      await _saveRecent(recent);
    } catch (e) {
      debugPrint('[BoundedRecentListStore:$storageKey] Error removing: $e');
    }
  }

  /// Whether any items are currently stored under [storageKey].
  ///
  /// [KeyValueStore.containsKey] is async (it may be backed by more than
  /// SharedPreferences), so this is `Future<bool>` rather than the
  /// synchronous `bool` the original `RecentlyWatchedStorage.
  /// hasRecentlyWatched()` used — that method reads `SharedPreferences`
  /// directly and keeps its own synchronous signature unchanged.
  Future<bool> hasRecent() => _store.containsKey(storageKey);

  Future<int> getRecentCount() async {
    final recent = await getRecent();
    return recent.length;
  }

  Future<void> _saveRecent(List<T> items) async {
    final json = jsonEncode(items.map(toJson).toList());
    await _store.setString(storageKey, json);
  }
}
