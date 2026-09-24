import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'iptv_providers.dart' show sharedPreferencesProvider;

const browseGridTvPeekEnabledStorageKey = 'browse_grid_tv_peek_enabled';

/// TV-only muted live preview on the focused library tile. Default off until
/// Fire TV qualification (`docs/designs/browse-grid-live-preview.md`).
final browseGridTvPeekEnabledProvider =
    StateNotifierProvider<BrowseGridTvPeekEnabledNotifier, bool>(
      (ref) => BrowseGridTvPeekEnabledNotifier(ref),
    );

class BrowseGridTvPeekEnabledNotifier extends StateNotifier<bool> {
  BrowseGridTvPeekEnabledNotifier(this._ref) : super(false) {
    _loadFromStorage();
  }

  final Ref _ref;

  void setEnabled(bool enabled) {
    state = enabled;
    _saveToStorage();
  }

  Future<void> _loadFromStorage() async {
    try {
      final prefs = _ref.read(sharedPreferencesProvider);
      state = prefs.getBool(browseGridTvPeekEnabledStorageKey) ?? false;
    } catch (_) {
      // keep default
    }
  }

  Future<void> _saveToStorage() async {
    try {
      final prefs = _ref.read(sharedPreferencesProvider);
      await prefs.setBool(browseGridTvPeekEnabledStorageKey, state);
    } catch (_) {
      // keep in-memory
    }
  }
}

/// Web has no preview surface; phone ignores peek regardless of the flag.
bool browseGridTvPeekAllowedOnPlatform({required bool isPhoneWidth}) {
  if (kIsWeb || isPhoneWidth) return false;
  return true;
}
