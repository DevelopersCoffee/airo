import 'dart:io';

import 'package:feature_mind/src/agent_chat/data/repositories/chat_workspace_store.dart';
import 'package:feature_mind/src/agent_chat/data/repositories/chat_workspace_store_io.dart';
import 'package:feature_mind/src/agent_chat/domain/models/chat_entity_graph.dart';
import 'package:feature_mind/src/agent_chat/domain/models/chat_transcript_turn.dart';
import 'package:feature_mind/src/agent_chat/domain/models/chat_workspace_layout.dart';
import 'package:feature_mind/src/provenance/domain/models/extracted_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('memory workspace lists chats newest first', () async {
    final store = MemoryChatWorkspaceStore();
    final first = await store.createChat();
    await store.replaceTranscript(first, [
      ChatTranscriptTurn(
        role: 'user',
        text: 'Older claim',
        createdAt: DateTime.utc(2026, 8, 1),
      ),
    ]);
    final second = await store.createChat();
    await store.replaceTranscript(second, [
      ChatTranscriptTurn(
        role: 'user',
        text: 'Newer claim',
        createdAt: DateTime.utc(2026, 8, 21),
      ),
    ]);

    final chats = await store.listChats();
    expect(chats.map((chat) => chat.title).toList(), [
      'Newer claim',
      'Older claim',
    ]);
  });

  test(
    'IO workspace uses Cursor chats/<id>/<id>.jsonl plus directory/',
    () async {
      final root = await Directory.systemTemp.createTemp('airo_mind_chats_');
      addTearDown(() => root.delete(recursive: true));
      final store = IoChatWorkspaceStore(root);
      final id = await store.createChat();

      expect(
        File(
          '${root.path}/${ChatWorkspaceLayout.transcriptPath(id)}',
        ).existsSync(),
        isTrue,
      );

      await store.replaceTranscript(id, [
        ChatTranscriptTurn(
          role: 'user',
          text: 'Niva Bupa Claim ID 9001001',
          createdAt: DateTime.utc(2026, 8, 21),
        ),
      ]);
      await store.saveDirectory(
        const ChatEntityGraph(
          nodes: [
            ChatGraphNode(
              id: 'organization:niva-bupa',
              type: EntityType.organization,
              name: 'Niva Bupa',
            ),
          ],
        ),
      );

      expect(
        File('${root.path}/${ChatWorkspaceLayout.directoryPath}').existsSync(),
        isTrue,
      );
      final chats = await store.listChats();
      expect(chats, hasLength(1));
      expect(chats.single.title, contains('9001001'));
      final directory = await store.loadDirectory();
      expect(directory.nodes.single.name, 'Niva Bupa');
    },
  );
}
