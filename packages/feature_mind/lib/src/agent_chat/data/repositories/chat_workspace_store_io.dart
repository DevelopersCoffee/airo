import 'dart:convert';
import 'dart:io';

import 'package:core_workers/core_workers.dart';
import 'package:path/path.dart' as p;

import '../../domain/models/chat_entity_graph.dart';
import '../../domain/models/chat_transcript_turn.dart';
import '../../domain/models/chat_workspace_layout.dart';
import 'chat_workspace_store.dart';

/// File-backed workspace. Cursor's shape: `directory/graph.json` plus
/// `chats/<id>/<id>.jsonl`.
class IoChatWorkspaceStore implements ChatWorkspaceStore {
  IoChatWorkspaceStore(this.root);

  final Directory root;

  static const _offMainBytes = 50 * 1024;

  Directory get _chatsDir =>
      Directory('${root.path}/${ChatWorkspaceLayout.chatsFolder}');

  File _file(String relative) => File('${root.path}/$relative');

  @override
  Future<ChatEntityGraph> loadDirectory() async {
    return _readGraph(_file(ChatWorkspaceLayout.directoryPath));
  }

  @override
  Future<void> saveDirectory(ChatEntityGraph graph) async {
    await _writeGraph(_file(ChatWorkspaceLayout.directoryPath), graph);
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
  Future<String> createChat() async {
    final id = newChatId();
    final folder = Directory(
      '${root.path}/${ChatWorkspaceLayout.chatFolder(id)}',
    );
    await folder.create(recursive: true);
    await _file(ChatWorkspaceLayout.transcriptPath(id)).create();
    return id;
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
}
