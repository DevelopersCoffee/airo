import 'package:core_data/core_data.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:platform_channels/platform_channels.dart';

import 'bounded_recent_list_store.dart';

/// Storage service for a "continue watching" / recently-opened VOD list.
///
/// Same storage engine as `RecentlyWatchedStorage` (device-local
/// [SharedPreferences] via [KeyValueStore]), under a separate storage key
/// so live-channel and VOD history never collide. There is no
/// resume-position/progress field — like `RecentlyWatchedStorage`, this
/// tracks "recently opened," not "resume playback at timestamp X."
class VodWatchHistoryStorage {
  static const String _recentKey = 'vod_recently_watched';
  static const int _maxRecentSize = 20;

  final BoundedRecentListStore<VodItem> _store;

  VodWatchHistoryStorage(
    SharedPreferences prefs, {
    KeyValueStore? store,
    int maxPreferenceValueBytes = kKeyValueStorePreferenceMaxValueBytes,
  }) : _store = BoundedRecentListStore<VodItem>(
         store ??
             PreferencesStore(prefs, maxValueBytes: maxPreferenceValueBytes),
         storageKey: _recentKey,
         maxSize: _maxRecentSize,
         idOf: (item) => item.id,
         toJson: (item) => item.toJson(),
         fromJson: VodItem.fromJson,
       );

  Future<void> addToRecent(VodItem item) => _store.addToRecent(item);

  Future<List<VodItem>> getRecentlyWatched({int? limit}) =>
      _store.getRecent(limit: limit);

  Future<void> clearRecent() => _store.clearRecent();

  Future<void> removeFromRecent(String id) => _store.removeFromRecent(id);

  Future<bool> hasRecentlyWatched() => _store.hasRecent();

  Future<int> getRecentCount() => _store.getRecentCount();
}
