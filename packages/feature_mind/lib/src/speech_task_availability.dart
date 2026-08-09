import 'dart:io';

import 'package:flutter/foundation.dart';

import 'bridges/mind_speech_bridge.dart';
import 'mind_service.dart' show MindUnavailable;
import 'model_installer.dart';
import 'models/model_provider.dart';

/// Whether a speech-shaped `AiTask` (`core_ai`'s `AiTask.speechToText` /
/// `AiTask.textToSpeech`) can be served right now.
///
/// # Why this exists instead of a router
///
/// `core_ai`'s `TaskModelRouter` resolves text/vision tasks against
/// `ModelCatalog`, choosing among *installed alternatives*. Airo Mind has
/// exactly one speech engine (whisper.cpp, pinned — see
/// `MindSpeechBridge`'s own doc comment) and no text-to-speech capability at
/// all, so there is nothing to choose between. A chooser with one option
/// would look complete while solving nothing; this answers the question
/// `TaskModelRouter` throws `UnroutableTaskException` for instead —
/// truthfully, not by faking a selection
/// (`tasks/mind-stt-tts-routing-plan.md`, Phase 0).
///
/// [unavailableReason] is null in two different cases, distinguished by
/// [available]: when [available] is true, it means "not applicable, this
/// works." When [available] is false and [unavailableReason] is also null,
/// it means the task has no implementation in Airo Mind at all, on any
/// platform or build — not one of `MindService`'s startup failure modes.
/// `AiTask.textToSpeech` is always this case: reusing a `MindUnavailable`
/// value for it would misdescribe a permanent product gap as a fixable
/// startup condition.
@immutable
class SpeechTaskAvailability {
  const SpeechTaskAvailability.available()
    : available = true,
      unavailableReason = null,
      detail = '';

  const SpeechTaskAvailability.unavailable(this.unavailableReason, this.detail)
    : available = false;

  final bool available;
  final MindUnavailable? unavailableReason;
  final String detail;
}

/// Answers [SpeechTaskAvailability] for the speech-shaped `AiTask` values,
/// without the side effects `MindService.initialize()` has: this checks
/// whether the model is present, it does not download it, and it never loads
/// the generation library.
class SpeechTaskAvailabilityChecker {
  const SpeechTaskAvailabilityChecker({
    MindSpeechBridge? speechBridge,
    ModelProvider? modelProvider,
  }) : _speech = speechBridge ?? const RustMindSpeechBridge(),
       _models = modelProvider ?? const ModelInstaller();

  final MindSpeechBridge _speech;
  final ModelProvider _models;

  /// `AiTask.speechToText`'s availability, using the same checks
  /// `MindService.initialize()` runs before it would start a model
  /// acquisition or a load.
  Future<SpeechTaskAvailability> speechToText(Directory modelsDir) async {
    try {
      await _speech.loadLibrary();
    } on Object catch (e) {
      return SpeechTaskAvailability.unavailable(
        MindUnavailable.bridgeMissing,
        '$e',
      );
    }

    if (!await _models.isInstalled(modelsDir)) {
      return const SpeechTaskAvailability.unavailable(
        MindUnavailable.modelsMissing,
        'The speech model is not installed yet.',
      );
    }

    return const SpeechTaskAvailability.available();
  }

  /// `AiTask.textToSpeech` is not available for Airo Mind — there is no
  /// text-to-speech engine in `feature_mind`. Airo's accessibility TTS
  /// (`app/lib/core/accessibility/airo_speech_service.dart`) is a distinct
  /// product surface and must not be reported here: doing so would claim a
  /// capability this package does not have.
  SpeechTaskAvailability textToSpeech() =>
      const SpeechTaskAvailability.unavailable(
        null,
        'Airo Mind has no text-to-speech capability.',
      );
}
