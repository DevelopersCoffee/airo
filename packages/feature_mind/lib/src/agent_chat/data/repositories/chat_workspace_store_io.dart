import 'dart:convert';
import 'dart:io';

import 'package:core_workers/core_workers.dart';
import 'package:path/path.dart' as p;

import '../../domain/models/chat_entity_graph.dart';
import '../../domain/models/chat_transcript_turn.dart';
import '../../domain/models/chat_workspace_layout.dart';
import 'chat_workspace_store.dart';

/// File-backed workspace. Cursor's shape: shared folder KV plus
/// `chats/<id>/<id>.jsonl`.
class IoChatWorkspaceStore implements ChatWorkspaceStore {
  IoChatWorkspaceStore(this.root);

  final Directory root;

  static const _offMainBytes = 50 * 1024;

  Directory get _chatsDir =>
      Directory('${root.path}/${ChatWorkspaceLayout.chatsFolder}');

  File _file(String relative) => File('${root.path}/$relative');

  File get _foldersIndex => _file(ChatWorkspaceLayout.foldersIndexFile);

  @override
  Future<ChatEntityGraph> loadDirectory() async {
    return _readGraph(_file(ChatWorkspaceLayout.directoryPath));
  }

  @override
  Future<void> saveDirectory(ChatEntityGraph graph) async {
    await _writeGraph(_file(ChatWorkspaceLayout.directoryPath), graph);
  }

  @override
  Future<ChatEntityGraph> loadSharedGraph(String? folderId) async {
    if (folderId == null) return loadDirectory();
    return _readGraph(_file(ChatWorkspaceLayout.folderGraphPath(folderId)));
  }

  @override
  Future<void> saveSharedGraph(String? folderId, ChatEntityGraph graph) async {
    if (folderId == null) {
      await saveDirectory(graph);
      return;
    }
    await _writeGraph(
      _file(ChatWorkspaceLayout.folderGraphPath(folderId)),
      graph,
    );
  }

  @override
  Future<List<MindChatFolder>> listFolders() async => _readFolders();

  @override
  Future<MindChatFolder> createFolder(String name) async {
    final folder = MindChatFolder(id: newChatId(), name: name.trim());
    final folders = await _readFolders();
    folders.add(folder);
    await _writeFolders(folders);
    await _writeGraph(
      _file(ChatWorkspaceLayout.folderGraphPath(folder.id)),
      ChatEntityGraph.empty,
    );
    return folder;
  }

  @override
  Future<void> updateFolder(MindChatFolder folder) async {
    final folders = await _readFolders();
    final index = folders.indexWhere((item) => item.id == folder.id);
    if (index < 0) return;
    folders[index] = folder;
    await _writeFolders(folders);
  }

  @override
  Future<void> moveChatToFolder(String chatId, String? folderId) async {
    await _writeMeta(chatId, folderId);
    if (folderId == null) return;
    final chatGraph = await loadChatGraph(chatId);
    final shared = await loadSharedGraph(folderId);
    await saveSharedGraph(folderId, shared.merge(chatGraph));
  }

  @override
  Future<List<MindChatRecord>> listChats() async {
    if (!await _chatsDir.exists()) return const [];
    final records = <MindChatRecord>[];
    await for (final entity in _chatsDir.list()) {
      if (entity is! Directory) continue;
      final id = p.basename(entity.path);
      if (id.isEmpty) continue;
      final turns = await loadTranscript(id);
      final stat = await entity.stat();
      final updated = turns.isEmpty ? stat.modified : turns.last.createdAt;
      records.add(
        MindChatRecord(
          id: id,
          title: MindChatRecord.titleFromTurns(turns),
          updatedAt: updated,
          preview: turns.isEmpty ? '' : turns.last.text.trim(),
          folderId: await _readFolderId(id),
        ),
      );
    }
    records.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return records;
  }

  @override
  Future<List<ChatTranscriptTurn>> loadTranscript(String id) async {
    final file = _file(ChatWorkspaceLayout.transcriptPath(id));
    if (!await file.exists()) return const [];
    final bytes = await file.readAsBytes();
    final raw = utf8.decode(bytes);
    if (bytes.length > _offMainBytes) {
      return runOffMain(() => ChatTranscriptTurn.parseLines(raw));
    }
    return ChatTranscriptTurn.parseLines(raw);
  }

  @override
  Future<void> replaceTranscript(
    String id,
    List<ChatTranscriptTurn> turns,
  ) async {
    final file = _file(ChatWorkspaceLayout.transcriptPath(id));
    await file.parent.create(recursive: true);
    if (turns.isEmpty) {
      if (await file.exists()) await file.writeAsString('');
      return;
    }
    final payload = turns.map((turn) => turn.toJsonl()).join('\n');
    await file.writeAsString('$payload\n');
  }

  @override
  Future<void> saveChatGraph(String id, ChatEntityGraph graph) async {
    await _writeGraph(_file(ChatWorkspaceLayout.chatGraphPath(id)), graph);
  }

  @override
  Future<ChatEntityGraph> loadChatGraph(String id) async {
    return _readGraph(_file(ChatWorkspaceLayout.chatGraphPath(id)));
  }

  @override
  Future<String> createChat({String? folderId}) async {
    final id = newChatId();
    final folder = Directory(
      '${root.path}/${ChatWorkspaceLayout.chatFolder(id)}',
    );
    await folder.create(recursive: true);
    await _file(ChatWorkspaceLayout.transcriptPath(id)).create();
    if (folderId != null) await _writeMeta(id, folderId);
    return id;
  }

  @override
  Future<void> deleteChat(String id) async {
    final folder = Directory(
      '${root.path}/${ChatWorkspaceLayout.chatFolder(id)}',
    );
    if (await folder.exists()) {
      await folder.delete(recursive: true);
    }
  }

  Future<ChatEntityGraph> _readGraph(File file) async {
    if (!await file.exists()) return ChatEntityGraph.empty;
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) return ChatEntityGraph.empty;
    final raw = utf8.decode(bytes);
    final decoded = bytes.length > _offMainBytes
        ? await runOffMain(() => jsonDecode(raw))
        : jsonDecode(raw);
    if (decoded is! Map) return ChatEntityGraph.empty;
    return ChatEntityGraph.fromJson(Map<String, dynamic>.from(decoded));
  }

  Future<void> _writeGraph(File file, ChatEntityGraph graph) async {
    await file.parent.create(recursive: true);
    final encoded = jsonEncode(graph.toJson());
    await file.writeAsString(encoded);
  }

  Future<List<MindChatFolder>> _readFolders() async {
    if (!await _foldersIndex.exists()) return [];
    final raw = await _foldersIndex.readAsString();
    if (raw.trim().isEmpty) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return [];
    final items = decoded['folders'];
    if (items is! List) return [];
    return [
      for (final item in items)
        if (item is Map)
          MindChatFolder.fromJson(Map<String, dynamic>.from(item)),
    ];
  }

  Future<void> _writeFolders(List<MindChatFolder> folders) async {
    await _foldersIndex.parent.create(recursive: true);
    await _foldersIndex.writeAsString(
      jsonEncode({
        'folders': [for (final folder in folders) folder.toJson()],
      }),
    );
  }

  Future<String?> _readFolderId(String chatId) async {
    final file = _file(ChatWorkspaceLayout.chatMetaPath(chatId));
    if (!await file.exists()) return null;
    final raw = await file.readAsString();
    if (raw.trim().isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    final folderId = decoded['folderId'];
    if (folderId is! String || folderId.isEmpty) return null;
    return folderId;
  }

  Future<void> _writeMeta(String chatId, String? folderId) async {
    final file = _file(ChatWorkspaceLayout.chatMetaPath(chatId));
    await file.parent.create(recursive: true);
    if (folderId == null || folderId.isEmpty) {
      if (await file.exists()) await file.delete();
      return;
    }
    await file.writeAsString(jsonEncode({'folderId': folderId}));
  }
}
