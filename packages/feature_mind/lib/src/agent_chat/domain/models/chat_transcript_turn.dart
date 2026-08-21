import 'dart:convert';

/// One JSONL line in a chat transcript. Shape follows Cursor agent
/// transcripts: `role` plus `message.content[]` text parts.
class ChatTranscriptTurn {
  const ChatTranscriptTurn({
    required this.role,
    required this.text,
    required this.createdAt,
    this.runId,
  });

  final String role;
  final String text;
  final DateTime createdAt;
  final String? runId;

  bool get isUser => role == 'user';

  Map<String, Object?> toJson() => {
    'role': role,
    'message': {
      'content': [
        {'type': 'text', 'text': text},
      ],
    },
    'createdAt': createdAt.toUtc().toIso8601String(),
    if (runId != null) 'runId': runId,
  };

  String toJsonl() => jsonEncode(toJson());

  static ChatTranscriptTurn? fromJson(Object? value) {
    if (value is! Map) return null;
    final role = value['role'];
    if (role is! String || (role != 'user' && role != 'assistant')) {
      return null;
    }
    final text = _textOf(value);
    if (text == null) return null;
    final createdAtRaw = value['createdAt'];
    final createdAt = createdAtRaw is String
        ? DateTime.tryParse(createdAtRaw) ?? DateTime.now().toUtc()
        : DateTime.now().toUtc();
    final runId = value['runId'];
    return ChatTranscriptTurn(
      role: role,
      text: text,
      createdAt: createdAt.toLocal(),
      runId: runId is String && runId.isNotEmpty ? runId : null,
    );
  }

  static List<ChatTranscriptTurn> parseLines(String raw) {
    if (raw.trim().isEmpty) return const [];
    final turns = <ChatTranscriptTurn>[];
    for (final line in raw.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      try {
        final decoded = jsonDecode(trimmed);
        final turn = fromJson(decoded);
        if (turn != null) turns.add(turn);
      } on Object {
        // A torn tail line is dropped, same as NotesOperationLog.
      }
    }
    return turns;
  }

  static String? _textOf(Map value) {
    final message = value['message'];
    if (message is Map) {
      final content = message['content'];
      if (content is List) {
        final buffer = StringBuffer();
        for (final part in content) {
          if (part is Map && part['type'] == 'text') {
            final text = part['text'];
            if (text is String && text.isNotEmpty) {
              if (buffer.isNotEmpty) buffer.writeln();
              buffer.write(text);
            }
          }
        }
        final joined = buffer.toString();
        if (joined.isNotEmpty) return joined;
      }
    }
    final legacy = value['text'];
    return legacy is String && legacy.isNotEmpty ? legacy : null;
  }
}

class MindChatRecord {
  const MindChatRecord({
    required this.id,
    required this.title,
    required this.updatedAt,
    this.preview = '',
  });

  final String id;
  final String title;
  final DateTime updatedAt;
  final String preview;

  static String titleFromTurns(Iterable<ChatTranscriptTurn> turns) {
    for (final turn in turns) {
      if (!turn.isUser) continue;
      final line = turn.text.trim().split('\n').first.trim();
      if (line.isEmpty) continue;
      return line.length <= 48 ? line : '${line.substring(0, 45).trim()}…';
    }
    return 'New chat';
  }
}
