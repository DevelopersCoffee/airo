class AssistantChatContextMessage {
  const AssistantChatContextMessage({required this.text, required this.isUser});

  final String text;
  final bool isUser;
}

class AssistantChatContextBuilder {
  const AssistantChatContextBuilder({
    this.maxHistoryMessages = 6,
    this.maxMessageChars = 280,
  });

  final int maxHistoryMessages;
  final int maxMessageChars;

  String buildSystemPrompt({
    required String currentUserPrompt,
    required List<AssistantChatContextMessage> history,
    bool compact = false,
    List<String> pluginPlaybooks = const [],
    String? pinnedPersonaIdentity,
  }) {
    final normalizedPrompt = currentUserPrompt.trim();
    final recentHistory = _recentHistory(history, normalizedPrompt);
    final pluginSection = pluginPlaybooks.isEmpty
        ? null
        : pinnedPersonaIdentity == null
        ? 'Enabled plugins:\n${pluginPlaybooks.join('\n\n')}'
        : pluginPlaybooks.join('\n\n');
    if (pinnedPersonaIdentity != null &&
        pinnedPersonaIdentity.trim().isNotEmpty) {
      final sections = <String>[
        pinnedPersonaIdentity.trim(),
        if (pluginSection != null) pluginSection,
        if (recentHistory.isNotEmpty)
          'Recent conversation:\n${recentHistory.join('\n')}',
        'Answer the last user message as this assistant. Do not switch roles.',
      ];
      return sections.join('\n\n');
    }
    if (compact) {
      final sections = <String>[
        pluginSection == null ? _airoCompactContext : _airoCompactPluginContext,
        if (pluginSection != null) pluginSection,
        if (recentHistory.isNotEmpty)
          'Recent conversation:\n${recentHistory.join('\n')}',
        'Answer the last user message directly. Do not continue system notices, invent a project setup, or repeat a previous reply.',
      ];
      return sections.join('\n\n');
    }
    final sections = <String>[
      _airoBaseContext,
      if (pluginSection != null) pluginSection,
      if (recentHistory.isNotEmpty)
        'Recent conversation:\n${recentHistory.join('\n')}',
      'Assume "Airo" refers to this app and assistant unless the user clearly means something else.',
      'Use the recent conversation for continuity so the user does not need to restate prior context.',
      'Answer only the latest user question. Do not repeat a previous greeting, meal-ideas pitch, or capability list unless they asked for that.',
    ];
    return sections.join('\n\n');
  }

  List<String> _recentHistory(
    List<AssistantChatContextMessage> history,
    String currentUserPrompt,
  ) {
    final normalizedCurrentPrompt = _normalizeForComparison(currentUserPrompt);
    final filtered = history
        .where((message) => message.text.trim().isNotEmpty)
        .where((message) => !isAssistantOperationalStatus(message.text))
        .where(
          (message) =>
              message.isUser || !looksLikeUnsolicitedMealPitch(message.text),
        )
        .where(
          (message) =>
              !message.isUser ||
              _normalizeForComparison(message.text) != normalizedCurrentPrompt,
        )
        .toList();
    if (filtered.isEmpty) {
      return const [];
    }

    final sliced = filtered.length <= maxHistoryMessages
        ? filtered
        : filtered.sublist(filtered.length - maxHistoryMessages);

    return sliced
        .map(
          (message) =>
              '${message.isUser ? 'User' : 'Airo'}: '
              '${_preview(message.text.trim())}',
        )
        .where((entry) => entry.trim().isNotEmpty)
        .toList(growable: false);
  }

  String _preview(String value) {
    if (value.length <= maxMessageChars) {
      return value;
    }
    return '${value.substring(0, maxMessageChars)}...';
  }

  String _normalizeForComparison(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

  /// Recovery for PD-CONTEXT-001 / PD-PERF-001: keep identity, drop noise.
  AssistantChatContextBuilder rebuildForBudget() => AssistantChatContextBuilder(
    maxHistoryMessages: 2,
    maxMessageChars: maxMessageChars > 280 ? 280 : maxMessageChars,
  );
}

/// Status / setup copy that must never be fed back into the local model.
bool isAssistantOperationalStatus(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return false;
  if (trimmed.startsWith('You selected ') &&
      (trimmed.contains('Warming it on device') ||
          trimmed.contains('Cloud runtime is ready'))) {
    return true;
  }
  if (trimmed.contains('no longer in the catalog')) return true;
  if (trimmed == 'Choose a project category before starting chat.') {
    return true;
  }
  return false;
}

/// Gemma often copied an unsolicited meal-ideas greeting into later turns.
bool looksLikeUnsolicitedMealPitch(String text) {
  final lower = text.toLowerCase();
  return lower.contains('healthy and delicious meal') ||
      (lower.contains('meal ideas') &&
          (lower.contains('dietary restrictions') ||
              lower.contains('what kind of meals')));
}

const String _airoCompactContext =
    'You are Airo, a local on-device assistant. '
    'Reply briefly and stay on the user\'s last question.';

const String _airoCompactPluginContext =
    'You are Airo, a local on-device assistant. '
    'Stay on the user\'s last question. '
    'Reply briefly unless an enabled plugin applies, then follow it fully.';

const String _airoBaseContext =
    'You are Airo, the assistant inside the Airo app. '
    'Airo is a local-first AI assistant that helps users chat, plan tasks, '
    'reason through work, summarize notes, open Airo features, manage '
    'reminders and notifications, help with calendar flows, capture expense '
    'messages into Coins, split bills, and support image or audio workflows '
    'when the selected runtime allows it. '
    'Answer as the Airo product assistant, stay grounded in these capabilities, '
    'and avoid acting like you have never heard of Airo.';
