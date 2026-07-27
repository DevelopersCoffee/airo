import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'iptv_providers.dart' show sharedPreferencesProvider;

enum AiroTvControlRow {
  channel('channel', 'Channel'),
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
      for (final row in AiroTvControlRow.values) row: true,
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
