import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'channel_filters_provider.dart';
import 'iptv_providers.dart' show sharedPreferencesProvider;

const savedFiltersStorageKey = 'iptv_saved_filters';

class SavedFiltersNotifier extends StateNotifier<List<ChannelFilters>> {
  SavedFiltersNotifier(this._ref) : super(const []) {
    unawaited(_load());
  }

  final Ref _ref;

  void save(ChannelFilters filters) {
    if (!filters.isActive || state.contains(filters)) return;
    _update([...state, filters]);
  }

  void remove(ChannelFilters filters) {
    _update(state.where((value) => value != filters).toList(growable: false));
  }

  void _update(List<ChannelFilters> next) {
    state = List.unmodifiable(next);
    unawaited(_persist(state));
  }

  Future<void> _load() async {
    try {
      final encoded = _ref
          .read(sharedPreferencesProvider)
          .getString(savedFiltersStorageKey);
      if (encoded == null) return;
      final parsed = jsonDecode(encoded);
      if (parsed is! List) return;
      state = List.unmodifiable([
        for (final value in parsed)
          if (value is Map<String, dynamic>)
            ChannelFilters.fromJson(value.cast<String, Object?>()),
      ]);
    } catch (_) {
      // Corrupt preferences are ignored without affecting browsing.
    }
  }

  Future<void> _persist(List<ChannelFilters> filters) async {
    try {
      await _ref
          .read(sharedPreferencesProvider)
          .setString(
            savedFiltersStorageKey,
            jsonEncode(filters.map((item) => item.toJson()).toList()),
          );
    } catch (_) {
      // Preference failures must not affect local browsing.
    }
  }
}

final savedFiltersProvider =
    StateNotifierProvider<SavedFiltersNotifier, List<ChannelFilters>>(
      (ref) => SavedFiltersNotifier(ref),
    );
