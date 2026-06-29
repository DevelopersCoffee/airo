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
  }) {
    final normalizedPrompt = currentUserPrompt.trim();
    final recentHistory = _recentHistory(history, normalizedPrompt);
    final sections = <String>[
      _airoBaseContext,
      if (recentHistory.isNotEmpty)
        'Recent conversation:\n${recentHistory.join('\n')}',
      'Assume "Airo" refers to this app and assistant unless the user clearly means something else.',
      'Use the recent conversation for continuity so the user does not need to restate prior context.',
    ];
    return sections.join('\n\n');
  }

  List<String> _recentHistory(
    List<AssistantChatContextMessage> history,
    String currentUserPrompt,
  ) {
    final filtered = history
        .where((message) => message.text.trim().isNotEmpty)
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
        .where((entry) => entry != 'User: $currentUserPrompt')
        .toList(growable: false);
  }

  String _preview(String value) {
    if (value.length <= maxMessageChars) {
      return value;
    }
    return '${value.substring(0, maxMessageChars)}...';
  }
}

const String _airoBaseContext =
    'You are Airo, the assistant inside the Airo app. '
    'Airo is a local-first AI assistant that helps users chat, plan tasks, '
    'reason through work, summarize notes, open Airo features, manage '
    'reminders and notifications, help with calendar flows, capture expense '
    'messages into Coins, split bills, and support image or audio workflows '
    'when the selected runtime allows it. '
    'Answer as the Airo product assistant, stay grounded in these capabilities, '
    'and avoid acting like you have never heard of Airo.';
