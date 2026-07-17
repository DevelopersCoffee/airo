import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:platform_player/platform_player.dart';
import 'iptv_providers.dart' show sharedPreferencesProvider;

const videoAspectRatioStorageKey = 'video_aspect_ratio';

/// Persisted user preference (CV-031) for the video aspect-ratio fit,
/// reachable both from the in-player quick toggle and the Playback settings
/// screen. Lives in this package (not the app layer) since VideoPlayerWidget
/// is the primary consumer and mutator — avoids a two-way app<->package sync.
class VideoAspectRatioNotifier extends StateNotifier<AiroPlaybackViewFit> {
  final Ref _ref;

  VideoAspectRatioNotifier(this._ref) : super(AiroPlaybackViewFit.contain) {
    _loadFromStorage();
  }

  void setAspectRatio(AiroPlaybackViewFit fit) {
    state = fit;
    _saveToStorage();
  }

  /// Cycles to the next fit in enum declaration order, wrapping around.
  void cycleToNext() {
    final values = AiroPlaybackViewFit.values;
    final nextIndex = (values.indexOf(state) + 1) % values.length;
    setAspectRatio(values[nextIndex]);
  }

  Future<void> _loadFromStorage() async {
    try {
      final prefs = _ref.read(sharedPreferencesProvider);
      final stored = prefs.getString(videoAspectRatioStorageKey);
      if (stored != null) {
        state = AiroPlaybackViewFit.values.firstWhere(
          (value) => value.stableId == stored,
          orElse: () => AiroPlaybackViewFit.contain,
        );
      }
    } catch (e) {
      // Failed to load, keep default
    }
  }

  Future<void> _saveToStorage() async {
    try {
      final prefs = _ref.read(sharedPreferencesProvider);
      await prefs.setString(videoAspectRatioStorageKey, state.stableId);
    } catch (e) {
      // Failed to save
    }
  }
}

final videoAspectRatioProvider =
    StateNotifierProvider<VideoAspectRatioNotifier, AiroPlaybackViewFit>(
      (ref) => VideoAspectRatioNotifier(ref),
    );
