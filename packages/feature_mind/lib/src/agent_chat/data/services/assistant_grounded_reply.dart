/// Deterministic answers for questions local GGUF models mishandle.
///
/// Identity, capabilities, and selected-model facts must not go through the
/// skill JSON router or a sticky system prompt.
class AssistantGroundedReply {
  const AssistantGroundedReply._();

  static const capabilitiesMessage =
      'I can chat on this device, use enabled skills, check your schedule, '
      'set reminders, split bills, draft diet plans, plan routines, and open '
      'Airo tools such as Money, Games, Reader, and model management.\n\n'
      'Ask a question, or tell me which of those to do.';

  static String? tryHandle({
    required String prompt,
    String? selectedModelName,
    String? selectedModelId,
  }) {
    final lower = prompt.trim().toLowerCase();
    if (lower.isEmpty) return null;
    if (_looksLikeCapabilities(lower)) return capabilitiesMessage;
    if (_looksLikeModelIdentity(lower)) {
      return _modelMessage(
        selectedModelName: selectedModelName,
        selectedModelId: selectedModelId,
        askedAboutTraining: _looksLikeTrainingQuestion(lower),
      );
    }
    return null;
  }

  static bool _looksLikeCapabilities(String lower) {
    if (lower.contains('same response') || lower.contains('again and again')) {
      return false;
    }
    return lower.contains('what can you do') ||
        lower.contains('what can u do') ||
        lower.contains('what can i do') ||
        lower.contains('what do you do') ||
        lower.contains('what do u do') ||
        lower.contains('what are you capable') ||
        ((lower.contains('what can airo do') ||
                lower.contains('what does airo do')) &&
            !lower.contains(' for ') &&
            !lower.contains(' with '));
  }

  static bool _looksLikeModelIdentity(String lower) {
    if (_looksLikeTrainingQuestion(lower)) return true;
    final asksWhich =
        lower.contains('what model') ||
        lower.contains('which model') ||
        lower.contains('what llm') ||
        lower.contains('which llm');
    return asksWhich &&
        (lower.contains('using') ||
            lower.contains('usig') ||
            lower.contains('we') ||
            lower.contains('you') ||
            lower.contains('u ') ||
            lower.contains('selected') ||
            lower.contains('running') ||
            lower.endsWith('model') ||
            lower.endsWith('llm'));
  }

  static bool _looksLikeTrainingQuestion(String lower) {
    if (lower.contains('train')) return true;
    return lower.contains('cutoff') ||
        (lower.contains('last time') && lower.contains('model'));
  }

  static String _modelMessage({
    required String? selectedModelName,
    required String? selectedModelId,
    required bool askedAboutTraining,
  }) {
    final name = selectedModelName?.trim();
    if (name == null || name.isEmpty) {
      return 'No chat model is selected yet. Open Project setup and choose one.';
    }
    final id = selectedModelId?.trim();
    final idSuffix = id == null || id.isEmpty || id == name ? '' : ' ($id)';
    if (askedAboutTraining) {
      return 'Airo does not store a training-cutoff date for this local '
          'package. The selected model is $name$idSuffix. It is a frozen GGUF '
          'file on this device — it is not being retrained while you chat.';
    }
    return 'This chat is using $name$idSuffix, running locally on this device.';
  }
}
