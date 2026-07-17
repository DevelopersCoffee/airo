import 'dart:convert';

import 'package:core_data/core_data.dart';

/// Persists user-configured overrides mapping an [IPTVChannel.id] to the
/// EPG `channelId` that should be used when querying [CompactEpgRepository]
/// for that channel — for when tvg-id auto-matching fails (a common
/// real-world IPTV pain point per CV-015 slice 2's scope).
///
/// Stored as a single JSON map under one preference key — the whole map is
/// read/written together since override counts are small (dozens, not
/// thousands) and this mirrors the simplicity of other small preference
/// blobs in this codebase (e.g. `RecentlyWatchedStorage`'s single JSON list).
class EpgChannelMatchOverrideStore {
  EpgChannelMatchOverrideStore(this._store);

  static const String _storageKey = 'epg_channel_match_overrides';

  final KeyValueStore _store;

  Future<void> setOverride({
    required String channelId,
    required String epgChannelId,
  }) async {
    final overrides = await getOverrides();
    overrides[channelId] = epgChannelId;
    await _save(overrides);
  }

  Future<void> clearOverride(String channelId) async {
    final overrides = await getOverrides();
    overrides.remove(channelId);
    await _save(overrides);
  }

  Future<Map<String, String>> getOverrides() async {
    final json = await _store.getString(_storageKey);
    if (json == null) return {};
    final decoded = jsonDecode(json) as Map<String, dynamic>;
    return decoded.map((key, value) => MapEntry(key, value as String));
  }

  Future<String?> resolveEpgChannelId(String channelId) async {
    final overrides = await getOverrides();
    return overrides[channelId];
  }

  Future<void> _save(Map<String, String> overrides) async {
    await _store.setString(_storageKey, jsonEncode(overrides));
  }
}
