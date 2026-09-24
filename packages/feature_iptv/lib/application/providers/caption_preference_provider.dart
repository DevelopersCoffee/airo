import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../caption_appearance.dart';
import 'iptv_providers.dart' show sharedPreferencesProvider;

const captionPreferenceEnabledStorageKey = 'caption_preference_enabled';
const captionPreferenceLanguageStorageKey = 'caption_preference_language';
const captionPreferenceTextSizeStorageKey = 'caption_preference_text_size';
const captionPreferenceTextColorStorageKey = 'caption_preference_text_color';

/// Persisted user preference (CV-008) for whether captions should be
/// re-enabled automatically when a stream exposes a matching subtitle
/// track, and which language to prefer.
///
/// The last-selected [languageCode] is remembered even after captions are
/// turned off, so re-enabling them doesn't lose the user's language choice.
class CaptionPreference {
  const CaptionPreference({
    this.enabled = false,
    this.languageCode,
    this.textSize = CaptionTextSize.standard,
    this.textColor = CaptionTextColor.white,
  });

  final bool enabled;
  final String? languageCode;
  final CaptionTextSize textSize;
  final CaptionTextColor textColor;

  CaptionPreference copyWith({
    bool? enabled,
    String? languageCode,
    CaptionTextSize? textSize,
    CaptionTextColor? textColor,
  }) {
    return CaptionPreference(
      enabled: enabled ?? this.enabled,
      languageCode: languageCode ?? this.languageCode,
      textSize: textSize ?? this.textSize,
      textColor: textColor ?? this.textColor,
    );
  }
}

/// Lives in this package (not the app layer) since VideoPlayerWidget is the
/// primary consumer and mutator — mirrors [VideoAspectRatioNotifier]'s
/// storage pattern (CV-031).
class CaptionPreferenceNotifier extends StateNotifier<CaptionPreference> {
  CaptionPreferenceNotifier(this._ref) : super(const CaptionPreference()) {
    _loadFromStorage();
  }

  final Ref _ref;

  void setCaptionPreference({required bool enabled, String? languageCode}) {
    state = state.copyWith(enabled: enabled, languageCode: languageCode);
    _saveToStorage();
  }

  /// Toggles captions on/off without touching the remembered language.
  void setCaptionsEnabled(bool enabled) {
    state = state.copyWith(enabled: enabled);
    _saveToStorage();
  }

  void setCaptionTextSize(CaptionTextSize size) {
    state = state.copyWith(textSize: size);
    _saveToStorage();
  }

  void setCaptionTextColor(CaptionTextColor color) {
    state = state.copyWith(textColor: color);
    _saveToStorage();
  }

  Future<void> _loadFromStorage() async {
    try {
      final prefs = _ref.read(sharedPreferencesProvider);
      state = CaptionPreference(
        enabled: prefs.getBool(captionPreferenceEnabledStorageKey) ?? false,
        languageCode: prefs.getString(captionPreferenceLanguageStorageKey),
        textSize: CaptionTextSize.fromStableId(
          prefs.getString(captionPreferenceTextSizeStorageKey),
        ),
        textColor: CaptionTextColor.fromStableId(
          prefs.getString(captionPreferenceTextColorStorageKey),
        ),
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
      await prefs.setString(
        captionPreferenceTextSizeStorageKey,
        state.textSize.stableId,
      );
      await prefs.setString(
        captionPreferenceTextColorStorageKey,
        state.textColor.stableId,
      );
    } catch (e) {
      // Failed to save
    }
  }
}

final captionPreferenceProvider =
    StateNotifierProvider<CaptionPreferenceNotifier, CaptionPreference>(
      (ref) => CaptionPreferenceNotifier(ref),
    );
