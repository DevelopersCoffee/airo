import 'package:core_data/core_data.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:platform_channels/platform_channels.dart';

import 'bounded_recent_list_store.dart';

/// Storage service for persisting recently watched IPTV channels.
///
/// Uses the platform key-value preference guard for local device storage.
/// Maintains privacy by storing data only on device.
///
/// Delegates to [BoundedRecentListStore] — the underlying storage key
/// (`iptv_recently_watched`), max size (20), and every method's behavior
/// are unchanged from before this delegation; this is a pure refactor.
class RecentlyWatchedStorage {
  static const String _recentKey = 'iptv_recently_watched';
  static const int _maxRecentSize = 20;

  final SharedPreferences _prefs;
  final BoundedRecentListStore<IPTVChannel> _store;

  RecentlyWatchedStorage(
    this._prefs, {
    KeyValueStore? store,
    int maxPreferenceValueBytes = kKeyValueStorePreferenceMaxValueBytes,
  }) : _store = BoundedRecentListStore<IPTVChannel>(
         store ??
             PreferencesStore(_prefs, maxValueBytes: maxPreferenceValueBytes),
         storageKey: _recentKey,
         maxSize: _maxRecentSize,
         idOf: (channel) => channel.id,
         toJson: (channel) => channel.toJson(),
         fromJson: IPTVChannel.fromJson,
       );

  /// Add channel to recently watched list.
  ///
  /// If channel already exists, moves it to the top.
  /// Maintains max size of [_maxRecentSize] channels.
  Future<void> addToRecent(IPTVChannel channel) => _store.addToRecent(channel);

  /// Get list of recently watched channels, most recently watched first.
  Future<List<IPTVChannel>> getRecentlyWatched({int? limit}) =>
      _store.getRecent(limit: limit);

  /// Clear all recently watched history.
  Future<void> clearRecent() => _store.clearRecent();

  /// Remove a specific channel from recently watched.
  Future<void> removeFromRecent(String channelId) =>
      _store.removeFromRecent(channelId);

  /// Check if there are any recently watched channels.
  bool hasRecentlyWatched() => _prefs.containsKey(_recentKey);

  /// Get the count of recently watched channels.
  Future<int> getRecentCount() => _store.getRecentCount();
}
