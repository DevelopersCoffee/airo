import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:platform_media/platform_media.dart';
import 'package:platform_player/platform_player.dart';

import 'iptv_providers.dart' show iptvStreamingServiceProvider, sharedPreferencesProvider;

/// Persisted Spatial Mode preference (#2083 minimal — engine hook #2081).
///
/// Original is default. Spatial engages the post-decode identity processor on
/// Android TV builds that ship the forked `video_player_android`.
class SpatialAudioModeNotifier extends StateNotifier<AiroSpatialAudioMode> {
  SpatialAudioModeNotifier(this._ref) : super(AiroSpatialAudioMode.original) {
    _loadFromStorage();
  }

  static const storageKey = 'aika_stream_spatial_audio_mode';

  final Ref _ref;

  Future<void> setMode(AiroSpatialAudioMode mode) async {
    state = mode;
    try {
      await _ref
          .read(sharedPreferencesProvider)
          .setString(storageKey, mode.stableId);
    } catch (_) {
      // Preference failures must not break playback.
    }
    await _applyToEngine(mode);
  }

  Future<void> _applyToEngine(AiroSpatialAudioMode mode) async {
    try {
      final service = _ref.read(iptvStreamingServiceProvider);
      if (service is VideoPlayerStreamingService) {
        await service.setSpatialAudioMode(mode);
      }
    } catch (_) {
      // Engine may not be ready in tests; ignore.
    }
  }

  void _loadFromStorage() {
    try {
      final stored = _ref
          .read(sharedPreferencesProvider)
          .getString(storageKey);
      final mode = AiroSpatialAudioMode.fromStableId(stored);
      if (mode != null) {
        state = mode;
        _applyToEngine(mode);
      }
    } catch (_) {
      // Keep default when preferences are unavailable.
    }
  }
}

final spatialAudioModeProvider =
    StateNotifierProvider<SpatialAudioModeNotifier, AiroSpatialAudioMode>(
      (ref) => SpatialAudioModeNotifier(ref),
    );
