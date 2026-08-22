import 'package:meta/meta.dart';

@immutable
class AddonConversationMessage {
  const AddonConversationMessage({
    required this.text,
    required this.isUser,
  });

  final String text;
  final bool isUser;
}

@immutable
class AddonConversation {
  const AddonConversation({
    required this.currentPrompt,
    this.history = const [],
    this.threadId = '',
    this.turnRevision = '',
  });

  final String currentPrompt;
  final List<AddonConversationMessage> history;
  final String threadId;
  final String turnRevision;
}
