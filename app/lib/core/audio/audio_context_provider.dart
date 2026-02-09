import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'audio_context_manager.dart';
import 'audio_context_settings_provider.dart';

// Re-export settings provider types
export 'audio_context_settings_provider.dart'
    show
        audioContextManagerProvider,
        audioContextSettingsProvider,
        autoResumeEnabledProvider;

/// Provider for audio context changes stream
final audioContextChangesProvider = StreamProvider<AudioContextChange>((ref) {
  final manager = ref.watch(audioContextManagerProvider);
  return manager.contextChanges;
});

/// Provider for current audio focus
final currentAudioFocusProvider = Provider<AudioFocusType?>((ref) {
  final manager = ref.watch(audioContextManagerProvider);
  // Watch the stream to trigger rebuilds
  ref.watch(audioContextChangesProvider);
  return manager.currentFocus;
});

/// Provider for whether music is ducked
final isMusicDuckedProvider = Provider<bool>((ref) {
  final manager = ref.watch(audioContextManagerProvider);
  ref.watch(audioContextChangesProvider);
  return manager.isDucked;
});

/// Provider for whether music is paused by context
final isMusicPausedByContextProvider = Provider<bool>((ref) {
  final manager = ref.watch(audioContextManagerProvider);
  ref.watch(audioContextChangesProvider);
  return manager.isPausedByContext;
});

/// Provider for current volume multiplier
final audioVolumeMultiplierProvider = Provider<double>((ref) {
  final manager = ref.watch(audioContextManagerProvider);
  ref.watch(audioContextChangesProvider);
  return manager.volumeMultiplier;
});

/// Provider for ducking enabled setting
final duckingEnabledProvider = Provider<bool>((ref) {
  final manager = ref.watch(audioContextManagerProvider);
  return manager.duckingEnabled;
});

/// Provider for ducking level setting
final duckingLevelProvider = Provider<double>((ref) {
  final manager = ref.watch(audioContextManagerProvider);
  return manager.duckingLevel;
});

/// Provider for active focuses
final activeFocusesProvider = Provider<Set<AudioFocusType>>((ref) {
  final manager = ref.watch(audioContextManagerProvider);
  ref.watch(audioContextChangesProvider);
  return manager.activeFocuses;
});

/// Helper class for requesting/releasing focus with auto-cleanup
class AudioFocusRequest {
  final AudioContextManager _manager;
  final AudioFocusType _type;
  bool _isActive = false;

  AudioFocusRequest(this._manager, this._type);

  /// Request focus
  bool request() {
    if (_isActive) return true;
    _isActive = _manager.requestFocus(_type);
    return _isActive;
  }

  /// Release focus
  void release() {
    if (!_isActive) return;
    _manager.releaseFocus(_type);
    _isActive = false;
  }

  /// Whether focus is currently held
  bool get isActive => _isActive;
}

/// Provider family for creating focus requests
final audioFocusRequestProvider =
    Provider.family<AudioFocusRequest, AudioFocusType>((ref, type) {
      final manager = ref.watch(audioContextManagerProvider);
      final request = AudioFocusRequest(manager, type);
      ref.onDispose(() => request.release());
      return request;
    });
