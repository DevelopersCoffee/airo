import '../capture/domain/speech_language_mode.dart';

/// How language is being handled for a scribe/meeting surface (#1774).
///
/// Product UX only — the #1664 whisper language-pin plumbing stays out of
/// scope unless a thin read-only seam feeds [pinnedLanguageCode].
enum ScribeLanguageMode {
  /// English-only speech weights (historical MindService default).
  englishOnly,

  /// Multilingual weights / multi-locale capture (Mind shell default after
  /// #1769). Badge is shown because multi-language is active.
  multilingual,

  /// An explicit whisper.cpp language pin (`en`, `hi`, …). Badge shows the
  /// code so the person can see what was requested.
  pinned,

  /// Auto-detect still running, or no language signal available yet.
  unknown,

  /// Multilingual (or pinned) processing needs a model that is not on disk.
  modelMissing,
}

/// Immutable trust copy for scribe/meeting surfaces (#1774).
///
/// Keeps badge visibility and offline wording in one place so Audio Scribe,
/// meeting capture, and the meeting reader cannot drift into false cloud
/// claims or silent English-only assumptions.
///
/// Deliberately free of whisper FRB / freezed types so host widget tests can
/// exercise this without codegen.
class ScribeTrustState {
  const ScribeTrustState({
    required this.languageMode,
    this.pinnedLanguageCode,
    this.processingOnDevice = true,
    this.modelMissingDetail,
  });

  /// Meeting / whisper path with multilingual weights (#1769).
  const ScribeTrustState.meetingMultilingual()
    : languageMode = ScribeLanguageMode.multilingual,
      pinnedLanguageCode = null,
      processingOnDevice = true,
      modelMissingDetail = null;

  /// Audio Scribe listen-mode: platform STT with India locale preference.
  const ScribeTrustState.audioScribeListen()
    : languageMode = ScribeLanguageMode.multilingual,
      pinnedLanguageCode = null,
      processingOnDevice = true,
      modelMissingDetail = null;

  /// Maps Settings' [SpeechLanguageMode] (#1664 thin seam) into trust UX.
  factory ScribeTrustState.fromSpeechLanguageMode(
    SpeechLanguageMode mode, {
    bool modelMissing = false,
  }) {
    return ScribeTrustState.forSpeechModel(
      multilingual: mode.includesMultilingualModel,
      // English opt-in is english-only weights, not a visible `en` pin badge.
      pinnedLanguageCode: null,
      modelMissing: modelMissing,
    );
  }

  /// Maps the #1629 speech-model selector into trust UX without requiring
  /// the full #1664 pin UI. [multilingual] is true when multilingual whisper
  /// weights (or multi-locale STT) are active.
  factory ScribeTrustState.forSpeechModel({
    required bool multilingual,
    String? pinnedLanguageCode,
    bool modelMissing = false,
  }) {
    if (modelMissing) {
      return ScribeTrustState(
        languageMode: ScribeLanguageMode.modelMissing,
        pinnedLanguageCode: pinnedLanguageCode,
        processingOnDevice: true,
        modelMissingDetail: multilingual
            ? 'The multilingual speech model is not installed yet. '
                  'Install ggml-tiny.bin before recording Hindi, Marathi, '
                  'or mixed-language meetings.'
            : 'The speech model is not installed yet. Download it before '
                  'recording — transcription runs only after the weights '
                  'are on this device.',
      );
    }
    if (pinnedLanguageCode != null && pinnedLanguageCode.trim().isNotEmpty) {
      return ScribeTrustState(
        languageMode: ScribeLanguageMode.pinned,
        pinnedLanguageCode: pinnedLanguageCode.trim().toLowerCase(),
      );
    }
    return ScribeTrustState(
      languageMode: multilingual
          ? ScribeLanguageMode.multilingual
          : ScribeLanguageMode.englishOnly,
    );
  }

  final ScribeLanguageMode languageMode;
  final String? pinnedLanguageCode;
  final bool processingOnDevice;
  final String? modelMissingDetail;

  /// Settings-driven badge (#1774): always show so Auto vs English is never
  /// ambiguous on record surfaces. Unknown / model-missing stay visible too.
  bool get showLanguageBadge => true;

  String get languageBadgeLabel => switch (languageMode) {
    ScribeLanguageMode.englishOnly => SpeechLanguageMode.english.badgeLabel,
    ScribeLanguageMode.multilingual => SpeechLanguageMode.auto.badgeLabel,
    ScribeLanguageMode.pinned => 'Language: ${pinnedLanguageCode ?? 'unknown'}',
    ScribeLanguageMode.unknown => 'Language unknown',
    ScribeLanguageMode.modelMissing => 'Speech model missing',
  };

  /// Short supporting line under the badge — never claims cloud processing
  /// for the on-device meeting / scribe capture path.
  String get offlineCopy {
    if (languageMode == ScribeLanguageMode.modelMissing) {
      return modelMissingDetail ??
          'Speech models are not on this device yet. Nothing is uploaded '
              'while they are missing.';
    }
    if (!processingOnDevice) {
      // Reserved for a future hybrid path; meeting/scribe surfaces today
      // always pass true so this branch stays unused in production.
      return 'Processing may use a networked model you selected.';
    }
    if (languageMode == ScribeLanguageMode.unknown) {
      return 'Transcription stays on this device. Language has not been '
          'confirmed yet — auto-detect can mislabel short utterances.';
    }
    return 'Transcription runs on this device. Sharing is always an '
        'explicit action.';
  }

  /// Optional second line for unknown / missing / multilingual honesty.
  String? get honestyNote => switch (languageMode) {
    ScribeLanguageMode.unknown =>
      'Translation is never applied automatically — only when you ask.',
    ScribeLanguageMode.modelMissing =>
      'Airo Mind will not pretend multilingual capture works until the '
          'weights are installed.',
    ScribeLanguageMode.multilingual =>
      'Spoken language is kept as-is. Translate only when you choose to.',
    ScribeLanguageMode.pinned =>
      'Pinned language is a hint to the on-device model, not a cloud translate.',
    ScribeLanguageMode.englishOnly => null,
  };
}
