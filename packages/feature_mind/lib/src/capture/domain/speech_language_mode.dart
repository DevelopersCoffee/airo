/// Transcription language mode for meeting capture (#1664 / #1774).
///
/// Two product choices, not a full language picker:
/// - [auto] — multilingual whisper weights and per-recording auto-detect
///   (mixed Marathi / Hindi / English and similar code-switching).
/// - [english] — English-only weights and a pinned `"en"` hint, so English-only
///   users never have to download the multilingual model.
///
/// Maps to `MindService.initialize(speechLanguage:)` (which model loads) and
/// `MindService.process(language:)` (whisper.cpp language pin / auto-detect).
library;

enum SpeechLanguageMode {
  /// Multilingual model + auto-detect. Default for the Mind shell.
  auto,

  /// English-only model + pin `en`. Opt-in to skip the multilingual download.
  english;

  /// Product default: mixed-language meetings are first-class (#1629).
  static const SpeechLanguageMode fallback = SpeechLanguageMode.auto;

  String get storageValue => name;

  /// Badge / chip label on record surfaces.
  String get badgeLabel => switch (this) {
    SpeechLanguageMode.auto => 'Multilingual · auto-detect',
    SpeechLanguageMode.english => 'English',
  };

  /// Whisper.cpp language code for [MindService.process], or `null` to leave
  /// auto-detect on.
  String? get processLanguageCode => switch (this) {
    SpeechLanguageMode.auto => null,
    SpeechLanguageMode.english => 'en',
  };

  /// Whether first-run download must include the multilingual speech weights.
  bool get includesMultilingualModel => this == SpeechLanguageMode.auto;

  static SpeechLanguageMode fromStorageValue(String? value) {
    return SpeechLanguageMode.values.firstWhere(
      (mode) => mode.storageValue == value,
      orElse: () => fallback,
    );
  }
}
