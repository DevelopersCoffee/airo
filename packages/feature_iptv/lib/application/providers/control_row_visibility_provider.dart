import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'iptv_providers.dart' show sharedPreferencesProvider;

/// The chrome rows the Explorer-rows settings dialog can toggle.
///
/// There is deliberately no `channel` row any more: the LIVE identity strip
/// was replaced by `ChannelNameOverlay`, a transient badge on the video stage
/// itself, so there is nothing left below the stage for a toggle to hide.
/// Its old `iptv_row_channel_visible` preference key is simply ignored on
/// load — [_load] only reads keys derived from live enum values.
enum AiroTvControlRow {
  stats('stats', 'Stats'),
  filter('filter', 'Filters'),
  hotbar('hotbar', 'Hotbar'),
  playlist('playlist', 'Playlist');

  const AiroTvControlRow(this.storageName, this.label);

  final String storageName;
  final String label;

  String get storageKey => 'iptv_row_${storageName}_visible';
}

class ControlRowVisibilityState {
  const ControlRowVisibilityState(this.values);

  factory ControlRowVisibilityState.defaults() {
    return ControlRowVisibilityState({
      for (final row in AiroTvControlRow.values)
        // Stats is diagnostic/advanced info (codec, resolution, bitrate) —
        // useful, but not something most viewers need permanently taking up
        // a row above the grid. Off by default; the settings dialog turns
        // it back on, and that choice is persisted like any other row.
        row: row != AiroTvControlRow.stats,
    });
  }

  final Map<AiroTvControlRow, bool> values;

  bool isVisible(AiroTvControlRow row) => values[row] ?? true;

  ControlRowVisibilityState copyWith(AiroTvControlRow row, bool visible) {
    return ControlRowVisibilityState({...values, row: visible});
  }
}

class ControlRowVisibilityNotifier
    extends StateNotifier<ControlRowVisibilityState> {
  ControlRowVisibilityNotifier(this._ref)
    : super(ControlRowVisibilityState.defaults()) {
    _load();
  }

  final Ref _ref;

  Future<void> setVisible(AiroTvControlRow row, bool visible) async {
    state = state.copyWith(row, visible);
    try {
      await _ref
          .read(sharedPreferencesProvider)
          .setBool(row.storageKey, visible);
    } catch (_) {
      // Keep the in-memory setting when local persistence is unavailable.
    }
  }

  void _load() {
    try {
      final preferences = _ref.read(sharedPreferencesProvider);
      var loaded = state;
      for (final row in AiroTvControlRow.values) {
        final stored = preferences.getBool(row.storageKey);
        if (stored != null) loaded = loaded.copyWith(row, stored);
      }
      state = loaded;
    } catch (_) {
      // Defaults keep the shell usable when preferences are unavailable.
    }
  }
}

final controlRowVisibilityProvider =
    StateNotifierProvider<
      ControlRowVisibilityNotifier,
      ControlRowVisibilityState
    >((ref) => ControlRowVisibilityNotifier(ref));
