import 'package:core_data/core_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Storage service for persisting groups/categories the user has hidden.
///
/// Local-only, matching the roadmap policy of no cloud sync for favorites
/// (CV-021, issue #826). Hidden groups are keyed by the playlist's raw
/// group/category string, not a synthetic id -- there is no shared group
/// identity across BYOC sources.
class HiddenGroupsStorage {
  static const String _hiddenGroupsKey = 'iptv_hidden_group_ids';

  final KeyValueStore _store;

  HiddenGroupsStorage(
    SharedPreferences prefs, {
    KeyValueStore? store,
    int maxPreferenceValueBytes = kKeyValueStorePreferenceMaxValueBytes,
  }) : _store =
           store ??
           PreferencesStore(prefs, maxValueBytes: maxPreferenceValueBytes);

  /// All hidden group ids, in no particular order.
  Future<Set<String>> getHiddenGroupIds() async {
    final ids = await _store.getStringList(_hiddenGroupsKey);
    return ids?.toSet() ?? <String>{};
  }

  /// Whether [groupId] is currently hidden.
  Future<bool> isHidden(String groupId) async {
    final ids = await getHiddenGroupIds();
    return ids.contains(groupId);
  }

  /// Hide [groupId]. No-op if already hidden.
  Future<void> hideGroup(String groupId) async {
    final ids = await getHiddenGroupIds();
    if (ids.add(groupId)) {
      await _save(ids);
    }
  }

  /// Unhide [groupId]. No-op if not hidden.
  Future<void> unhideGroup(String groupId) async {
    final ids = await getHiddenGroupIds();
    if (ids.remove(groupId)) {
      await _save(ids);
    }
  }

  /// Toggle [groupId]'s hidden state. Returns the new state.
  Future<bool> toggleHidden(String groupId) async {
    final ids = await getHiddenGroupIds();
    final nowHidden = !ids.contains(groupId);
    if (nowHidden) {
      ids.add(groupId);
    } else {
      ids.remove(groupId);
    }
    await _save(ids);
    return nowHidden;
  }

  Future<void> _save(Set<String> ids) {
    return _store.setStringList(_hiddenGroupsKey, ids.toList(growable: false));
  }
}
