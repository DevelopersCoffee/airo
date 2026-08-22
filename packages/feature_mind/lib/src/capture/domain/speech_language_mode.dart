/// Transcription language for meeting capture and notebook ingest (#1664 / #1774).
///
/// [auto] loads multilingual whisper weights and leaves per-recording
/// auto-detect on — the right default for mixed Marathi / Hindi / English.
/// [english] pins `"en"` and skips the multilingual download.
/// Every other value loads the multilingual model and pins the whisper.cpp
/// language code, so a Hindi lecture is not left to auto-detect.
library;

enum SpeechLanguageMode {
  auto(
    whisperCode: null,
    englishOnly: false,
    badgeLabel: 'Multilingual · auto-detect',
    menuLabel: 'Auto (mixed)',
  ),
  english(
    whisperCode: 'en',
    englishOnly: true,
    badgeLabel: 'English',
    menuLabel: 'English',
  ),
  hindi(
    whisperCode: 'hi',
    englishOnly: false,
    badgeLabel: 'Hindi',
    menuLabel: 'Hindi · हिन्दी',
  ),
  marathi(
    whisperCode: 'mr',
    englishOnly: false,
    badgeLabel: 'Marathi',
    menuLabel: 'Marathi · मराठी',
  ),
  tamil(
    whisperCode: 'ta',
    englishOnly: false,
    badgeLabel: 'Tamil',
    menuLabel: 'Tamil · தமிழ்',
  ),
  telugu(
    whisperCode: 'te',
    englishOnly: false,
    badgeLabel: 'Telugu',
    menuLabel: 'Telugu · తెలుగు',
  ),
  bengali(
    whisperCode: 'bn',
    englishOnly: false,
    badgeLabel: 'Bengali',
    menuLabel: 'Bengali · বাংলা',
  ),
  gujarati(
    whisperCode: 'gu',
    englishOnly: false,
    badgeLabel: 'Gujarati',
    menuLabel: 'Gujarati · ગુજરાતી',
  ),
  kannada(
    whisperCode: 'kn',
    englishOnly: false,
    badgeLabel: 'Kannada',
    menuLabel: 'Kannada · ಕನ್ನಡ',
  ),
  malayalam(
    whisperCode: 'ml',
    englishOnly: false,
    badgeLabel: 'Malayalam',
    menuLabel: 'Malayalam · മലയാളം',
  ),
  punjabi(
    whisperCode: 'pa',
    englishOnly: false,
    badgeLabel: 'Punjabi',
    menuLabel: 'Punjabi · ਪੰਜਾਬੀ',
  ),
  urdu(
    whisperCode: 'ur',
    englishOnly: false,
    badgeLabel: 'Urdu',
    menuLabel: 'Urdu · اردو',
  ),
  sanskrit(
    whisperCode: 'sa',
    englishOnly: false,
    badgeLabel: 'Sanskrit',
    menuLabel: 'Sanskrit · संस्कृतम्',
  ),
  nepali(
    whisperCode: 'ne',
    englishOnly: false,
    badgeLabel: 'Nepali',
    menuLabel: 'Nepali · नेपाली',
  ),
  sinhala(
    whisperCode: 'si',
    englishOnly: false,
    badgeLabel: 'Sinhala',
    menuLabel: 'Sinhala · සිංහල',
  ),
  spanish(
    whisperCode: 'es',
    englishOnly: false,
    badgeLabel: 'Spanish',
    menuLabel: 'Spanish · Español',
  ),
  french(
    whisperCode: 'fr',
    englishOnly: false,
    badgeLabel: 'French',
    menuLabel: 'French · Français',
  ),
  german(
    whisperCode: 'de',
    englishOnly: false,
    badgeLabel: 'German',
    menuLabel: 'German · Deutsch',
  ),
  portuguese(
    whisperCode: 'pt',
    englishOnly: false,
    badgeLabel: 'Portuguese',
    menuLabel: 'Portuguese · Português',
  ),
  italian(
    whisperCode: 'it',
    englishOnly: false,
    badgeLabel: 'Italian',
    menuLabel: 'Italian · Italiano',
  ),
  dutch(
    whisperCode: 'nl',
    englishOnly: false,
    badgeLabel: 'Dutch',
    menuLabel: 'Dutch · Nederlands',
  ),
  russian(
    whisperCode: 'ru',
    englishOnly: false,
    badgeLabel: 'Russian',
    menuLabel: 'Russian · Русский',
  ),
  japanese(
    whisperCode: 'ja',
    englishOnly: false,
    badgeLabel: 'Japanese',
    menuLabel: 'Japanese · 日本語',
  ),
  korean(
    whisperCode: 'ko',
    englishOnly: false,
    badgeLabel: 'Korean',
    menuLabel: 'Korean · 한국어',
  ),
  chinese(
    whisperCode: 'zh',
    englishOnly: false,
    badgeLabel: 'Chinese',
    menuLabel: 'Chinese · 中文',
  ),
  arabic(
    whisperCode: 'ar',
    englishOnly: false,
    badgeLabel: 'Arabic',
    menuLabel: 'Arabic · العربية',
  ),
  turkish(
    whisperCode: 'tr',
    englishOnly: false,
    badgeLabel: 'Turkish',
    menuLabel: 'Turkish · Türkçe',
  ),
  polish(
    whisperCode: 'pl',
    englishOnly: false,
    badgeLabel: 'Polish',
    menuLabel: 'Polish · Polski',
  ),
  vietnamese(
    whisperCode: 'vi',
    englishOnly: false,
    badgeLabel: 'Vietnamese',
    menuLabel: 'Vietnamese · Tiếng Việt',
  ),
  indonesian(
    whisperCode: 'id',
    englishOnly: false,
    badgeLabel: 'Indonesian',
    menuLabel: 'Indonesian · Bahasa Indonesia',
  ),
  thai(
    whisperCode: 'th',
    englishOnly: false,
    badgeLabel: 'Thai',
    menuLabel: 'Thai · ไทย',
  ),
  ukrainian(
    whisperCode: 'uk',
    englishOnly: false,
    badgeLabel: 'Ukrainian',
    menuLabel: 'Ukrainian · Українська',
  ),
  swedish(
    whisperCode: 'sv',
    englishOnly: false,
    badgeLabel: 'Swedish',
    menuLabel: 'Swedish · Svenska',
  ),
  czech(
    whisperCode: 'cs',
    englishOnly: false,
    badgeLabel: 'Czech',
    menuLabel: 'Czech · Čeština',
  ),
  greek(
    whisperCode: 'el',
    englishOnly: false,
    badgeLabel: 'Greek',
    menuLabel: 'Greek · Ελληνικά',
  ),
  hebrew(
    whisperCode: 'he',
    englishOnly: false,
    badgeLabel: 'Hebrew',
    menuLabel: 'Hebrew · עברית',
  ),
  persian(
    whisperCode: 'fa',
    englishOnly: false,
    badgeLabel: 'Persian',
    menuLabel: 'Persian · فارسی',
  ),
  swahili(
    whisperCode: 'sw',
    englishOnly: false,
    badgeLabel: 'Swahili',
    menuLabel: 'Swahili · Kiswahili',
  ),
  filipino(
    whisperCode: 'tl',
    englishOnly: false,
    badgeLabel: 'Filipino',
    menuLabel: 'Filipino · Tagalog',
  ),
  malay(
    whisperCode: 'ms',
    englishOnly: false,
    badgeLabel: 'Malay',
    menuLabel: 'Malay · Bahasa Melayu',
  ),
  romanian(
    whisperCode: 'ro',
    englishOnly: false,
    badgeLabel: 'Romanian',
    menuLabel: 'Romanian · Română',
  ),
  hungarian(
    whisperCode: 'hu',
    englishOnly: false,
    badgeLabel: 'Hungarian',
    menuLabel: 'Hungarian · Magyar',
  ),
  finnish(
    whisperCode: 'fi',
    englishOnly: false,
    badgeLabel: 'Finnish',
    menuLabel: 'Finnish · Suomi',
  ),
  danish(
    whisperCode: 'da',
    englishOnly: false,
    badgeLabel: 'Danish',
    menuLabel: 'Danish · Dansk',
  ),
  norwegian(
    whisperCode: 'no',
    englishOnly: false,
    badgeLabel: 'Norwegian',
    menuLabel: 'Norwegian · Norsk',
  );

  const SpeechLanguageMode({
    required this.whisperCode,
    required this.englishOnly,
    required this.badgeLabel,
    required this.menuLabel,
  });

  /// Whisper.cpp language code, or `null` to leave auto-detect on.
  final String? whisperCode;

  /// When true, first-run download may skip multilingual speech weights.
  final bool englishOnly;

  /// Badge / chip label on record surfaces.
  final String badgeLabel;

  /// Settings dropdown row.
  final String menuLabel;

  /// Product default: mixed-language meetings are first-class (#1629).
  static const SpeechLanguageMode fallback = SpeechLanguageMode.auto;

  String get storageValue => name;

  /// Whisper.cpp language code for [MindService.process], or `null` to leave
  /// auto-detect on.
  String? get processLanguageCode => whisperCode;

  /// Whether first-run download must include the multilingual speech weights.
  bool get includesMultilingualModel => !englishOnly;

  /// Copy under the Settings tile.
  String get settingsSubtitle => switch (this) {
    SpeechLanguageMode.auto =>
      'Auto (mixed) — multilingual model, auto-detect per recording. '
          'Best for Marathi / Hindi / English code-switching.',
    SpeechLanguageMode.english =>
      'English — English-only model. Skips the multilingual download.',
    _ =>
      'Pins transcription to $badgeLabel (${whisperCode ?? 'auto'}). '
          'Uses the multilingual model.',
  };

  static SpeechLanguageMode fromStorageValue(String? value) {
    return SpeechLanguageMode.values.firstWhere(
      (mode) => mode.storageValue == value,
      orElse: () => fallback,
    );
  }

  static SpeechLanguageMode fromWhisperCode(String? code) {
    if (code == null || code.isEmpty) return fallback;
    return SpeechLanguageMode.values.firstWhere(
      (mode) => mode.whisperCode == code,
      orElse: () => fallback,
    );
  }
}
