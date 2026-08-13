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
