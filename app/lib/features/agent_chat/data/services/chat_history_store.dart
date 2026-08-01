import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// A bounded, versioned local chat-history store. Message text is kept on the
/// device; callers decide when a conversation should be exported or shared.
class ChatHistoryEntry {
  const ChatHistoryEntry({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });

  final String text;
  final bool isUser;
  final DateTime timestamp;

  Map<String, Object?> toJson() => {
    'text': text,
    'isUser': isUser,
    'timestamp': timestamp.toUtc().toIso8601String(),
  };

  static ChatHistoryEntry? fromJson(Object? value) {
    if (value is! Map) return null;
    final text = value['text'];
    final isUser = value['isUser'];
    final timestamp = value['timestamp'];
    if (text is! String || isUser is! bool || timestamp is! String) {
      return null;
    }
    final parsedTimestamp = DateTime.tryParse(timestamp);
    if (parsedTimestamp == null) return null;
    return ChatHistoryEntry(
      text: text,
      isUser: isUser,
      timestamp: parsedTimestamp.toLocal(),
    );
  }
}

class ChatHistoryStore {
  ChatHistoryStore({this.preferences});

  static const storageKey = 'airo_mind.chat_history.v1';
  static const schemaVersion = 1;
  static const maxEntries = 200;
  static const maxEntryCharacters = 20000;

  final SharedPreferences? preferences;
  Future<void> _writeTail = Future<void>.value();

  Future<List<ChatHistoryEntry>> load() async {
    // Do not read a partially updated snapshot while a queued write is still
    // committing. This keeps restore deterministic after rapid chat turns or
    // during route disposal.
    await _writeTail;
    final store = preferences ?? await SharedPreferences.getInstance();
    final raw = store.getString(storageKey);
    if (raw == null) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map || decoded['schemaVersion'] != schemaVersion) {
        return const [];
      }
      final entries = decoded['entries'];
      if (entries is! List) return const [];
      return entries
          .map(ChatHistoryEntry.fromJson)
          .whereType<ChatHistoryEntry>()
          .toList(growable: false);
    } on Object {
      return const [];
    }
  }

  Future<void> save(Iterable<ChatHistoryEntry> entries) async {
    final bounded = entries
        .where((entry) => entry.text.length <= maxEntryCharacters)
        .toList(growable: false);
    final start = bounded.length > maxEntries ? bounded.length - maxEntries : 0;
    final payload = jsonEncode({
      'schemaVersion': schemaVersion,
      'entries': bounded.skip(start).map((entry) => entry.toJson()).toList(),
    });
    return _enqueueWrite(() async {
      final store = preferences ?? await SharedPreferences.getInstance();
      await store.setString(storageKey, payload);
    });
  }

  Future<void> clear() {
    return _enqueueWrite(() async {
      final store = preferences ?? await SharedPreferences.getInstance();
      await store.remove(storageKey);
    });
  }

  Future<void> _enqueueWrite(Future<void> Function() operation) {
    final result = _writeTail.then<void>((_) => operation());
    // Keep the queue usable after a failed write, while still returning the
    // original error to the caller that requested this operation.
    _writeTail = result.then<void>((_) {}, onError: (_, _) {});
    return result;
  }
}
