import 'dart:convert';

import 'package:core_data/core_data.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'iptv_providers.dart' show sharedPreferencesProvider;

/// One channel assigned to a position in a saved layout. `channelName` is
/// cached at save time so the layout list can render without a live
/// catalog lookup (a channel could later be removed from the playlist).
class MultiviewCastLayoutSlot extends Equatable {
  const MultiviewCastLayoutSlot({
    required this.channelId,
    required this.channelName,
  });

  final String channelId;
  final String channelName;

  factory MultiviewCastLayoutSlot.fromJson(Map<String, dynamic> json) {
    return MultiviewCastLayoutSlot(
      channelId: json['channelId'] as String,
      channelName: json['channelName'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'channelId': channelId,
    'channelName': channelName,
  };

  @override
  List<Object?> get props => [channelId, channelName];
}

/// A named, ordered set of channels — "Launch" applies every slot to the
/// connected receiver in one action (see the Cast MultiView remote-control
/// spec's "Named saved layouts" scope item). Local-only, no cloud sync,
/// matching [FavoriteChannelsStorage]'s own policy.
class MultiviewCastLayout extends Equatable {
  const MultiviewCastLayout({
    required this.id,
    required this.name,
    required this.slots,
  });

  /// Stable across renames — generated once at creation, never reused.
  final String id;
  final String name;
  final List<MultiviewCastLayoutSlot> slots;

  factory MultiviewCastLayout.fromJson(Map<String, dynamic> json) {
    return MultiviewCastLayout(
      id: json['id'] as String,
      name: json['name'] as String,
      slots: [
        for (final rawSlot in json['slots'] as List)
          MultiviewCastLayoutSlot.fromJson(rawSlot as Map<String, dynamic>),
      ],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'slots': [for (final slot in slots) slot.toJson()],
  };

  MultiviewCastLayout copyWith({
    String? name,
    List<MultiviewCastLayoutSlot>? slots,
  }) {
    return MultiviewCastLayout(
      id: id,
      name: name ?? this.name,
      slots: slots ?? this.slots,
    );
  }

  @override
  List<Object?> get props => [id, name, slots];
}

/// Local storage for saved [MultiviewCastLayout]s.
class MultiviewCastLayoutStorage {
  static const String _layoutsKey = 'iptv_multiview_cast_layouts';

  final KeyValueStore _store;

  MultiviewCastLayoutStorage(
    SharedPreferences prefs, {
    KeyValueStore? store,
    int maxPreferenceValueBytes = kKeyValueStorePreferenceMaxValueBytes,
  }) : _store =
           store ??
           PreferencesStore(prefs, maxValueBytes: maxPreferenceValueBytes);

  /// Saved layouts, most-recently-saved last (insertion order — a layout
  /// re-saved via [saveLayout] keeps its original position).
  Future<List<MultiviewCastLayout>> getLayouts() async {
    final raw = await _store.getString(_layoutsKey);
    if (raw == null) return const [];
    final decoded = jsonDecode(raw) as List;
    return [
      for (final item in decoded)
        MultiviewCastLayout.fromJson(item as Map<String, dynamic>),
    ];
  }

  /// Adds a new layout, or replaces an existing one with the same [id].
  Future<void> saveLayout(MultiviewCastLayout layout) async {
    final layouts = await getLayouts();
    final index = layouts.indexWhere((existing) => existing.id == layout.id);
    final updated = [...layouts];
    if (index >= 0) {
      updated[index] = layout;
    } else {
      updated.add(layout);
    }
    await _save(updated);
  }

  /// Removes a layout by id. No-op if it isn't there.
  Future<void> deleteLayout(String id) async {
    final layouts = await getLayouts();
    final updated = layouts.where((layout) => layout.id != id).toList();
    if (updated.length != layouts.length) await _save(updated);
  }

  Future<void> _save(List<MultiviewCastLayout> layouts) {
    return _store.setString(
      _layoutsKey,
      jsonEncode([for (final layout in layouts) layout.toJson()]),
    );
  }
}

final multiviewCastLayoutStorageProvider = Provider<MultiviewCastLayoutStorage>(
  (ref) {
    return MultiviewCastLayoutStorage(ref.watch(sharedPreferencesProvider));
  },
);

/// Saved layouts, most-recently-saved last.
final multiviewCastLayoutsProvider = FutureProvider<List<MultiviewCastLayout>>((
  ref,
) {
  return ref.watch(multiviewCastLayoutStorageProvider).getLayouts();
});

int _layoutIdCounter = 0;

/// Generates a new layout id. Timestamp + a process-local counter rather
/// than a real UUID — good enough for a list scoped to one device's local
/// storage (avoids a new dependency for this one call site), and the
/// counter guards against two ids generated in the same microsecond.
String newMultiviewCastLayoutId() =>
    'layout-${DateTime.now().microsecondsSinceEpoch}-${_layoutIdCounter++}';

/// Saves [layout] and invalidates [multiviewCastLayoutsProvider] so any UI
/// watching the list picks up the change immediately.
final saveMultiviewCastLayoutProvider =
    Provider<Future<void> Function(MultiviewCastLayout)>((ref) {
      return (layout) async {
        await ref.read(multiviewCastLayoutStorageProvider).saveLayout(layout);
        ref.invalidate(multiviewCastLayoutsProvider);
      };
    });

/// Deletes the layout with [id] and invalidates [multiviewCastLayoutsProvider].
final deleteMultiviewCastLayoutProvider =
    Provider<Future<void> Function(String)>((ref) {
      return (id) async {
        await ref.read(multiviewCastLayoutStorageProvider).deleteLayout(id);
        ref.invalidate(multiviewCastLayoutsProvider);
      };
    });
