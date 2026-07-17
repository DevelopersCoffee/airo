import 'package:core_data/core_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Storage service for persisting a user's favorited IPTV channel ids.
///
/// Local-only, matching the roadmap policy of no cloud sync for favorites.
class FavoriteChannelsStorage {
  static const String _favoritesKey = 'iptv_favorite_channel_ids';

  final KeyValueStore _store;

  FavoriteChannelsStorage(
    SharedPreferences prefs, {
    KeyValueStore? store,
    int maxPreferenceValueBytes = kKeyValueStorePreferenceMaxValueBytes,
  }) : _store =
           store ??
           PreferencesStore(prefs, maxValueBytes: maxPreferenceValueBytes);

  /// All favorited channel ids, in no particular order.
  Future<Set<String>> getFavoriteChannelIds() async {
    final ids = await _store.getStringList(_favoritesKey);
    return ids?.toSet() ?? <String>{};
  }

  /// Whether [channelId] is currently favorited.
  Future<bool> isFavorite(String channelId) async {
    final ids = await getFavoriteChannelIds();
    return ids.contains(channelId);
  }

  /// Add [channelId] to favorites. No-op if already favorited.
  Future<void> addFavorite(String channelId) async {
    final ids = await getFavoriteChannelIds();
    if (ids.add(channelId)) {
      await _save(ids);
    }
  }

  /// Remove [channelId] from favorites. No-op if not favorited.
  Future<void> removeFavorite(String channelId) async {
    final ids = await getFavoriteChannelIds();
    if (ids.remove(channelId)) {
      await _save(ids);
    }
  }

  /// Toggle [channelId]'s favorite state. Returns the new state.
  Future<bool> toggleFavorite(String channelId) async {
    final ids = await getFavoriteChannelIds();
    final isNowFavorite = !ids.contains(channelId);
    if (isNowFavorite) {
      ids.add(channelId);
    } else {
      ids.remove(channelId);
    }
    await _save(ids);
    return isNowFavorite;
  }

  Future<void> _save(Set<String> ids) {
    return _store.setStringList(_favoritesKey, ids.toList(growable: false));
  }
}
