import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/iptv/application/providers/iptv_providers.dart'
    show sharedPreferencesProvider;
import 'audio_context_manager.dart';
import 'audio_context_settings.dart';

/// Audio context settings notifier for persisting user preferences
class AudioContextSettingsNotifier extends StateNotifier<AudioContextSettings> {
  final Ref _ref;
  static const String _storageKey = 'audio_context_settings';

  AudioContextSettingsNotifier(this._ref) : super(const AudioContextSettings()) {
    _loadFromStorage();
  }

  /// Set whether context-aware audio is enabled
  void setEnabled(bool enabled) {
    state = state.copyWith(enabled: enabled);
    _applyToManager();
    _saveToStorage();
  }

  /// Set ducking level (0.1 - 0.5)
  void setDuckingLevel(double level) {
    final clampedLevel = level.clamp(0.1, 0.5);
    state = state.copyWith(duckingLevel: clampedLevel);
    _applyToManager();
    _saveToStorage();
  }

  /// Set whether to auto-resume after interruptions
  void setAutoResume(bool autoResume) {
    // Store in feature rules with a special key
    final updatedRules = Map<String, FeatureAudioRule>.from(state.featureRules);
    updatedRules['_global'] = FeatureAudioRule(
      featureId: '_global',
      autoResume: autoResume,
    );
    state = state.copyWith(featureRules: updatedRules);
    _saveToStorage();
  }

  /// Get auto-resume setting
  bool get autoResumeEnabled {
    return state.featureRules['_global']?.autoResume ?? true;
  }

  /// Set duck during voice output
  void setDuckDuringVoiceOutput(bool duck) {
    state = state.copyWith(duckDuringVoiceOutput: duck);
    _saveToStorage();
  }

  /// Set duck during game SFX
  void setDuckDuringGameSfx(bool duck) {
    state = state.copyWith(duckDuringGameSfx: duck);
    _saveToStorage();
  }

  /// Set pause during video
  void setPauseDuringVideo(bool pause) {
    state = state.copyWith(pauseDuringVideo: pause);
    _saveToStorage();
  }

  /// Set pause during voice input
  void setPauseDuringVoiceInput(bool pause) {
    state = state.copyWith(pauseDuringVoiceInput: pause);
    _saveToStorage();
  }

  /// Reset to defaults
  void resetToDefaults() {
    state = const AudioContextSettings();
    _applyToManager();
    _saveToStorage();
  }

  /// Apply current settings to AudioContextManager
  void _applyToManager() {
    try {
      final manager = _ref.read(audioContextManagerProvider);
      manager.setDuckingEnabled(state.enabled);
      manager.setDuckingLevel(state.duckingLevel);
    } catch (e) {
      // Manager might not be available yet
    }
  }

  Future<void> _loadFromStorage() async {
    try {
      final prefs = _ref.read(sharedPreferencesProvider);
      final jsonString = prefs.getString(_storageKey);
      if (jsonString != null) {
        final json = jsonDecode(jsonString) as Map<String, dynamic>;
        state = AudioContextSettings.fromJson(json);
        // Apply loaded settings to manager
        _applyToManager();
      }
    } catch (e) {
      // Failed to load, keep defaults
    }
  }

  Future<void> _saveToStorage() async {
    try {
      final prefs = _ref.read(sharedPreferencesProvider);
      final jsonString = jsonEncode(state.toJson());
      await prefs.setString(_storageKey, jsonString);
    } catch (e) {
      // Failed to save
    }
  }
}

/// Audio context settings provider
final audioContextSettingsProvider =
    StateNotifierProvider<AudioContextSettingsNotifier, AudioContextSettings>(
  (ref) => AudioContextSettingsNotifier(ref),
);

/// Provider for AudioContextManager singleton
/// This replaces the one in audio_context_provider.dart to integrate with settings
final audioContextManagerProvider = Provider<AudioContextManager>((ref) {
  final manager = AudioContextManager();
  
  // Apply settings from storage when manager is created
  try {
    final settings = ref.watch(audioContextSettingsProvider);
    manager.setDuckingEnabled(settings.enabled);
    manager.setDuckingLevel(settings.duckingLevel);
  } catch (e) {
    // Settings not available yet, use defaults
  }
  
  ref.onDispose(() => manager.dispose());
  return manager;
});

/// Derived provider for auto-resume setting
final autoResumeEnabledProvider = Provider<bool>((ref) {
  final notifier = ref.watch(audioContextSettingsProvider.notifier);
  return notifier.autoResumeEnabled;
});

