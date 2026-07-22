import 'dart:async';
import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'channel_filters_provider.dart';
import 'iptv_providers.dart' show sharedPreferencesProvider;

const hotbarChannelsStorageKey = 'iptv_hotbar';

class HotbarChannelEntry extends Equatable {
  const HotbarChannelEntry({required this.channelId, required this.filters});

  final String channelId;
  final ChannelFilters filters;

  Map<String, Object?> toJson() => {
    'channelId': channelId,
    'filters': filters.toJson(),
  };

  factory HotbarChannelEntry.fromJson(Map<String, Object?> json) {
    final channelId = json['channelId'];
    final filters = json['filters'];
    if (channelId is! String || filters is! Map<String, dynamic>) {
      throw const FormatException('Invalid hotbar channel entry');
    }
    return HotbarChannelEntry(
      channelId: channelId,
      filters: ChannelFilters.fromJson(filters.cast<String, Object?>()),
    );
  }

  @override
  List<Object?> get props => [channelId, filters];
}

class HotbarChannelsNotifier extends StateNotifier<List<HotbarChannelEntry>> {
  HotbarChannelsNotifier(this._ref) : super(const []) {
    unawaited(_load());
  }

  final Ref _ref;

  void pin({required String channelId, required ChannelFilters filters}) {
    final entry = HotbarChannelEntry(channelId: channelId, filters: filters);
    if (state.contains(entry)) return;
    _update([...state, entry]);
  }

  void unpin(HotbarChannelEntry entry) {
    _update(state.where((value) => value != entry).toList(growable: false));
  }

  void _update(List<HotbarChannelEntry> next) {
    state = List.unmodifiable(next);
    unawaited(_persist(state));
  }

  Future<void> _load() async {
    try {
      final encoded = _ref
          .read(sharedPreferencesProvider)
          .getString(hotbarChannelsStorageKey);
      if (encoded == null) return;
      final parsed = jsonDecode(encoded);
      if (parsed is! List) return;
      final entries = <HotbarChannelEntry>[];
      for (final value in parsed) {
        if (value is! Map<String, dynamic>) continue;
        try {
          entries.add(
            HotbarChannelEntry.fromJson(value.cast<String, Object?>()),
          );
        } on FormatException {
          // One bad entry does not discard usable local shortcuts.
        }
      }
      state = List.unmodifiable(entries);
    } catch (_) {
      // Corrupt preferences are ignored without affecting browsing.
    }
  }

  Future<void> _persist(List<HotbarChannelEntry> entries) async {
    try {
      await _ref
          .read(sharedPreferencesProvider)
          .setString(
            hotbarChannelsStorageKey,
            jsonEncode(entries.map((item) => item.toJson()).toList()),
          );
    } catch (_) {
      // Preference failures must not affect local browsing.
    }
  }
}

final hotbarChannelsProvider =
    StateNotifierProvider<HotbarChannelsNotifier, List<HotbarChannelEntry>>(
      (ref) => HotbarChannelsNotifier(ref),
    );
