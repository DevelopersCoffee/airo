import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'iptv_providers.dart' show sharedPreferencesProvider;

/// Persisted preference for automatic system PiP when the user backgrounds
/// playback. Defaults to enabled to preserve existing Airo TV behavior.
class PictureInPicturePreferenceNotifier extends StateNotifier<bool> {
  PictureInPicturePreferenceNotifier(this._ref) : super(true) {
    _loadFromStorage();
  }

  static const storageKey = 'airo_tv_picture_in_picture_enabled';

  final Ref _ref;

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    try {
      await _ref.read(sharedPreferencesProvider).setBool(storageKey, enabled);
    } catch (_) {
      // Settings persistence failures should not break playback settings.
    }
  }

  void _loadFromStorage() {
    try {
      final stored = _ref.read(sharedPreferencesProvider).getBool(storageKey);
      if (stored != null) {
        state = stored;
      }
    } catch (_) {
      // Keep the default when preferences are unavailable or corrupt.
    }
  }
}

final pictureInPicturePreferenceProvider =
    StateNotifierProvider<PictureInPicturePreferenceNotifier, bool>(
      (ref) => PictureInPicturePreferenceNotifier(ref),
    );
