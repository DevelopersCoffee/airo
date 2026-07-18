import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'iptv_providers.dart' show sharedPreferencesProvider;

const tvFontModeStorageKey = 'tv_font_mode';

/// Persisted user preference (CV-008, UC-001) for TV UI text size.
enum TvFontMode {
  standard('standard', 1),
  large('large', 1.25),
  extraLarge('extra_large', 1.5);

  const TvFontMode(this.stableId, this.scale);

  final String stableId;

  /// Multiplier applied to a surface's base font size. TV channel/control
  /// text is expected to keep its existing `maxLines`/`overflow: ellipsis`
  /// handling at every scale rather than growing new overflow logic here.
  final double scale;
}

/// Lives in this package (not the app layer) since the TV channel grid and
/// controls are the primary consumers — mirrors [VideoAspectRatioNotifier]'s
/// storage pattern (CV-031).
class TvFontModeNotifier extends StateNotifier<TvFontMode> {
  final Ref _ref;

  TvFontModeNotifier(this._ref) : super(TvFontMode.standard) {
    _loadFromStorage();
  }

  void setTvFontMode(TvFontMode mode) {
    state = mode;
    _saveToStorage();
  }

  Future<void> _loadFromStorage() async {
    try {
      final prefs = _ref.read(sharedPreferencesProvider);
      final stored = prefs.getString(tvFontModeStorageKey);
      if (stored != null) {
        state = TvFontMode.values.firstWhere(
          (value) => value.stableId == stored,
          orElse: () => TvFontMode.standard,
        );
      }
    } catch (e) {
      // Failed to load, keep default
    }
  }

  Future<void> _saveToStorage() async {
    try {
      final prefs = _ref.read(sharedPreferencesProvider);
      await prefs.setString(tvFontModeStorageKey, state.stableId);
    } catch (e) {
      // Failed to save
    }
  }
}

final tvFontModeProvider =
    StateNotifierProvider<TvFontModeNotifier, TvFontMode>(
      (ref) => TvFontModeNotifier(ref),
    );
