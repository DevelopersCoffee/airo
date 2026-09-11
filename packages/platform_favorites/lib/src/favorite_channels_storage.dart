import 'package:core_data/core_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Storage for a user's favorited and "not for me" IPTV channel ids.
///
/// Local-only, matching the roadmap policy of no cloud sync for favorites.
/// Favorite and not-for-me are mutually exclusive by construction: setting
/// one always clears the other, enforced here (not by callers) so every
/// call site — the settings sheet, the LIVE bar's toggle, any future one —
/// inherits the invariant automatically.
class FavoriteChannelsStorage {
  static const String _favoritesKey = 'iptv_favorite_channel_ids';
  static const String _notForMeKey = 'iptv_not_for_me_channel_ids';

  final KeyValueStore _store;

  FavoriteChannelsStorage(
    SharedPreferences prefs, {
    KeyValueStore? store,
    int maxPreferenceValueBytes = kKeyValueStorePreferenceMaxValueBytes,
  }) : _store =
           store ??
           PreferencesStore(prefs, maxValueBytes: maxPreferenceValueBytes);

  /// Favorited channel ids, in the user's chosen order (append-on-favorite
  /// by default; a future manual-reorder feature can persist a new order
  /// through the same key without a format change).
  Future<List<String>> getFavoriteChannelIds() async {
    return await _store.getStringList(_favoritesKey) ?? const <String>[];
  }

  /// "Not for me" channel ids, in no particular order.
  Future<Set<String>> getNotForMeChannelIds() async {
    final ids = await _store.getStringList(_notForMeKey);
    return ids?.toSet() ?? <String>{};
  }

  Future<bool> isFavorite(String channelId) async {
    return (await getFavoriteChannelIds()).contains(channelId);
  }

  Future<bool> isNotForMe(String channelId) async {
    return (await getNotForMeChannelIds()).contains(channelId);
  }

  /// Favorite [channelId], clearing any existing not-for-me flag. No-op
  /// (beyond the exclusion clear) if already favorited.
  Future<void> setFavorite(String channelId) async {
    final favorites = List<String>.from(await getFavoriteChannelIds());
    final notForMe = await getNotForMeChannelIds();
    final favoritesChanged = !favorites.contains(channelId);
    final notForMeChanged = notForMe.remove(channelId);
    if (favoritesChanged) favorites.add(channelId);
    if (favoritesChanged || notForMeChanged) {
      await Future.wait([
        if (favoritesChanged) _saveFavorites(favorites),
        if (notForMeChanged) _saveNotForMe(notForMe),
      ]);
    }
  }

  /// Marks [channelId] as not for me, clearing any existing favorite flag.
  Future<void> setNotForMe(String channelId) async {
    final favorites = List<String>.from(await getFavoriteChannelIds());
    final notForMe = await getNotForMeChannelIds();
    final favoritesChanged = favorites.remove(channelId);
    final notForMeChanged = notForMe.add(channelId);
    if (favoritesChanged || notForMeChanged) {
      await Future.wait([
        if (favoritesChanged) _saveFavorites(favorites),
        if (notForMeChanged) _saveNotForMe(notForMe),
      ]);
    }
  }

  /// Clears both flags for [channelId]. No-op if neither was set.
  Future<void> clearPreference(String channelId) async {
    final favorites = List<String>.from(await getFavoriteChannelIds());
    final notForMe = await getNotForMeChannelIds();
    final favoritesChanged = favorites.remove(channelId);
    final notForMeChanged = notForMe.remove(channelId);
    await Future.wait([
      if (favoritesChanged) _saveFavorites(favorites),
      if (notForMeChanged) _saveNotForMe(notForMe),
    ]);
  }

  /// Toggle [channelId]'s favorite state (clearing not-for-me if setting).
  /// Returns the new favorite state. Kept for existing call sites.
  Future<bool> toggleFavorite(String channelId) async {
    final isNowFavorite = !await isFavorite(channelId);
    if (isNowFavorite) {
      await setFavorite(channelId);
    } else {
      await clearPreference(channelId);
    }
    return isNowFavorite;
  }

  /// Replaces the complete favorite list for an import/restore operation,
  /// preserving the given order. Does not touch not-for-me state.
  Future<void> replaceAll(Iterable<String> channelIds) {
    final normalized = <String>[];
    final seen = <String>{};
    for (final id in channelIds) {
      final trimmed = id.trim();
      if (trimmed.isEmpty || !seen.add(trimmed)) continue;
      normalized.add(trimmed);
    }
    return _saveFavorites(normalized);
  }

  Future<void> _saveFavorites(List<String> ids) {
    return _store.setStringList(_favoritesKey, ids);
  }

  Future<void> _saveNotForMe(Set<String> ids) {
    return _store.setStringList(_notForMeKey, ids.toList(growable: false));
  }
}
