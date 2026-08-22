import 'dart:math';

import '../../domain/models/chat_entity_graph.dart';
import '../../domain/models/chat_transcript_turn.dart';

/// Local chat workspace: a shared entity [directory] plus one transcript
/// folder per chat, the same split Cursor uses for files vs chats.
///
/// Chats can be classified into [MindChatFolder]s. Chats in the same folder
/// share that folder's knowledge graph (`loadSharedGraph`); unfiled chats
/// share [loadDirectory].
abstract class ChatWorkspaceStore {
  Future<ChatEntityGraph> loadDirectory();

  Future<void> saveDirectory(ChatEntityGraph graph);

  Future<ChatEntityGraph> loadSharedGraph(String? folderId);

  Future<void> saveSharedGraph(String? folderId, ChatEntityGraph graph);

  Future<List<MindChatFolder>> listFolders();

  Future<MindChatFolder> createFolder(String name);

  Future<void> updateFolder(MindChatFolder folder);

  Future<void> moveChatToFolder(String chatId, String? folderId);

  Future<List<MindChatRecord>> listChats();

  Future<List<ChatTranscriptTurn>> loadTranscript(String id);

  Future<void> replaceTranscript(String id, List<ChatTranscriptTurn> turns);

  Future<void> saveChatGraph(String id, ChatEntityGraph graph);

  Future<ChatEntityGraph> loadChatGraph(String id);

  Future<String> createChat({String? folderId});

  Future<void> deleteChat(String id);
}

/// In-memory workspace used by tests and as the web / plugin-missing fallback.
class MemoryChatWorkspaceStore implements ChatWorkspaceStore {
  MemoryChatWorkspaceStore();

  ChatEntityGraph directory = ChatEntityGraph.empty;
  final Map<String, ChatEntityGraph> folderGraphs = {};
  final List<MindChatFolder> folders = [];
  final Map<String, String> chatFolderIds = {};
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
  Future<ChatEntityGraph> loadSharedGraph(String? folderId) async {
    if (folderId == null) return directory;
    return folderGraphs[folderId] ?? ChatEntityGraph.empty;
  }

  @override
  Future<void> saveSharedGraph(String? folderId, ChatEntityGraph graph) async {
    if (folderId == null) {
      directory = graph;
      return;
    }
    folderGraphs[folderId] = graph;
  }

  @override
  Future<List<MindChatFolder>> listFolders() async =>
      List<MindChatFolder>.from(folders);

  @override
  Future<MindChatFolder> createFolder(String name) async {
    final folder = MindChatFolder(id: newChatId(), name: name.trim());
    folders.add(folder);
    folderGraphs[folder.id] = ChatEntityGraph.empty;
    return folder;
  }

  @override
  Future<void> updateFolder(MindChatFolder folder) async {
    final index = folders.indexWhere((item) => item.id == folder.id);
    if (index < 0) return;
    folders[index] = folder;
  }

  @override
  Future<void> moveChatToFolder(String chatId, String? folderId) async {
    if (!transcripts.containsKey(chatId)) return;
    if (folderId == null) {
      chatFolderIds.remove(chatId);
      return;
    }
    chatFolderIds[chatId] = folderId;
    final chatGraph = chatGraphs[chatId] ?? ChatEntityGraph.empty;
    final shared = folderGraphs[folderId] ?? ChatEntityGraph.empty;
    folderGraphs[folderId] = shared.merge(chatGraph);
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
        folderId: chatFolderIds[entry.key],
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
  Future<String> createChat({String? folderId}) async {
    final id = newChatId();
    transcripts[id] = const [];
    createdAt[id] = DateTime.now();
    if (folderId != null) chatFolderIds[id] = folderId;
    return id;
  }

  @override
  Future<void> deleteChat(String id) async {
    transcripts.remove(id);
    chatGraphs.remove(id);
    createdAt.remove(id);
    chatFolderIds.remove(id);
  }
}

String newChatId() {
  final random = Random();
  String hex(int n) =>
      List.generate(n, (_) => random.nextInt(16).toRadixString(16)).join();
  return '${hex(8)}-${hex(4)}-4${hex(3)}-${(8 + random.nextInt(4)).toRadixString(16)}${hex(3)}-${hex(12)}';
}
