import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'iptv_providers.dart' show sharedPreferencesProvider;

const captionPreferenceEnabledStorageKey = 'caption_preference_enabled';
const captionPreferenceLanguageStorageKey = 'caption_preference_language';

/// Persisted user preference (CV-008) for whether captions should be
/// re-enabled automatically when a stream exposes a matching subtitle
/// track, and which language to prefer.
///
/// The last-selected [languageCode] is remembered even after captions are
/// turned off, so re-enabling them doesn't lose the user's language choice.
class CaptionPreference {
  const CaptionPreference({this.enabled = false, this.languageCode});

  final bool enabled;
  final String? languageCode;

  CaptionPreference copyWith({bool? enabled, String? languageCode}) {
    return CaptionPreference(
      enabled: enabled ?? this.enabled,
      languageCode: languageCode ?? this.languageCode,
    );
  }
}

/// Lives in this package (not the app layer) since VideoPlayerWidget is the
/// primary consumer and mutator — mirrors [VideoAspectRatioNotifier]'s
/// storage pattern (CV-031).
class CaptionPreferenceNotifier extends StateNotifier<CaptionPreference> {
  final Ref _ref;

  CaptionPreferenceNotifier(this._ref) : super(const CaptionPreference()) {
    _loadFromStorage();
  }

  void setCaptionPreference({required bool enabled, String? languageCode}) {
    state = state.copyWith(enabled: enabled, languageCode: languageCode);
    _saveToStorage();
  }

  /// Toggles captions on/off without touching the remembered language.
  void setCaptionsEnabled(bool enabled) {
    state = state.copyWith(enabled: enabled);
    _saveToStorage();
  }

  Future<void> _loadFromStorage() async {
    try {
      final prefs = _ref.read(sharedPreferencesProvider);
      state = CaptionPreference(
        enabled: prefs.getBool(captionPreferenceEnabledStorageKey) ?? false,
        languageCode: prefs.getString(captionPreferenceLanguageStorageKey),
      );
    } catch (e) {
      // Failed to load, keep default
    }
  }

  Future<void> _saveToStorage() async {
    try {
      final prefs = _ref.read(sharedPreferencesProvider);
      await prefs.setBool(captionPreferenceEnabledStorageKey, state.enabled);
      if (state.languageCode != null) {
        await prefs.setString(
          captionPreferenceLanguageStorageKey,
          state.languageCode!,
        );
      }
    } catch (e) {
      // Failed to save
    }
  }
}

final captionPreferenceProvider =
    StateNotifierProvider<CaptionPreferenceNotifier, CaptionPreference>(
      (ref) => CaptionPreferenceNotifier(ref),
    );
