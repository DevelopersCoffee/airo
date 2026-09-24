import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'iptv_providers.dart' show sharedPreferencesProvider;

const audioPreferenceLanguageStorageKey = 'audio_preference_language';

/// Persisted preferred audio track language (CV-016). Unlike captions, audio
/// has no on/off gate — only the last [languageCode] is remembered.
class AudioPreferenceNotifier extends StateNotifier<String?> {
  AudioPreferenceNotifier(this._ref) : super(null) {
    _loadFromStorage();
  }

  final Ref _ref;

  void setPreferredLanguage(String languageCode) {
    state = languageCode;
    _saveToStorage();
  }

  Future<void> _loadFromStorage() async {
    try {
      final prefs = _ref.read(sharedPreferencesProvider);
      state = prefs.getString(audioPreferenceLanguageStorageKey);
    } catch (e) {
      // Failed to load, keep default
    }
  }

  Future<void> _saveToStorage() async {
    try {
      final prefs = _ref.read(sharedPreferencesProvider);
      await prefs.setString(audioPreferenceLanguageStorageKey, state!);
    } catch (e) {
      // Failed to save
    }
  }
}

final audioPreferenceProvider =
    StateNotifierProvider<AudioPreferenceNotifier, String?>(
      (ref) => AudioPreferenceNotifier(ref),
    );
