import 'dart:math';

import '../../domain/models/chat_entity_graph.dart';
import '../../domain/models/chat_transcript_turn.dart';

/// Local chat workspace: a shared entity [directory] plus one transcript
/// folder per chat, the same split Cursor uses for files vs chats.
abstract class ChatWorkspaceStore {
  Future<ChatEntityGraph> loadDirectory();

  Future<void> saveDirectory(ChatEntityGraph graph);

  Future<List<MindChatRecord>> listChats();

  Future<List<ChatTranscriptTurn>> loadTranscript(String id);

  Future<void> replaceTranscript(String id, List<ChatTranscriptTurn> turns);

  Future<void> saveChatGraph(String id, ChatEntityGraph graph);

  Future<ChatEntityGraph> loadChatGraph(String id);

  Future<String> createChat();
}

/// In-memory workspace used by tests and as the web / plugin-missing fallback.
class MemoryChatWorkspaceStore implements ChatWorkspaceStore {
  MemoryChatWorkspaceStore();

  ChatEntityGraph directory = ChatEntityGraph.empty;
  final Map<String, List<ChatTranscriptTurn>> transcripts = {};
  final Map<String, ChatEntityGraph> chatGraphs = {};
  final Map<String, DateTime> createdAt = {};

  @override
  Future<ChatEntityGraph> loadDirectory() async => directory;

  @override
  Future<void> saveDirectory(ChatEntityGraph graph) async {
    directory = graph;
  }

  @override
  Future<List<MindChatRecord>> listChats() async {
    final records = transcripts.entries.map((entry) {
      final turns = entry.value;
      final updated = turns.isEmpty
          ? (createdAt[entry.key] ?? DateTime.fromMillisecondsSinceEpoch(0))
          : turns.last.createdAt;
      return MindChatRecord(
        id: entry.key,
        title: MindChatRecord.titleFromTurns(turns),
        updatedAt: updated,
        preview: turns.isEmpty ? '' : turns.last.text.trim(),
      );
    }).toList();
    records.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return records;
  }

  @override
  Future<List<ChatTranscriptTurn>> loadTranscript(String id) async =>
      List<ChatTranscriptTurn>.from(transcripts[id] ?? const []);

  @override
  Future<void> replaceTranscript(
    String id,
    List<ChatTranscriptTurn> turns,
  ) async {
    transcripts[id] = List<ChatTranscriptTurn>.from(turns);
  }

  @override
  Future<void> saveChatGraph(String id, ChatEntityGraph graph) async {
    chatGraphs[id] = graph;
  }

  @override
  Future<ChatEntityGraph> loadChatGraph(String id) async =>
      chatGraphs[id] ?? ChatEntityGraph.empty;

  @override
  Future<String> createChat() async {
    final id = newChatId();
    transcripts[id] = const [];
    createdAt[id] = DateTime.now();
    return id;
  }
}

String newChatId() {
  final random = Random();
  String hex(int n) =>
      List.generate(n, (_) => random.nextInt(16).toRadixString(16)).join();
  return '${hex(8)}-${hex(4)}-4${hex(3)}-${(8 + random.nextInt(4)).toRadixString(16)}${hex(3)}-${hex(12)}';
}
