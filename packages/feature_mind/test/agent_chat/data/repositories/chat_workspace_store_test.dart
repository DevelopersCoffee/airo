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

  test('chats in a folder share that folder knowledge graph', () async {
    final store = MemoryChatWorkspaceStore();
    final folder = await store.createFolder('Study');
    final first = await store.createChat(folderId: folder.id);
    await store.saveChatGraph(
      first,
      const ChatEntityGraph(
        nodes: [
          ChatGraphNode(id: 'term:queue', type: EntityType.term, name: 'queue'),
        ],
      ),
    );
    await store.moveChatToFolder(first, folder.id);
    final second = await store.createChat(folderId: folder.id);

    final shared = await store.loadSharedGraph(folder.id);
    expect(shared.nodes.single.name, 'queue');
    expect((await store.listChats()).map((chat) => chat.folderId).toSet(), {
      folder.id,
    });
    expect(second, isNotEmpty);
  });

  test(
    'deleteChat removes the transcript and leaves folder knowledge',
    () async {
      final store = MemoryChatWorkspaceStore();
      final folder = await store.createFolder('Study');
      final id = await store.createChat(folderId: folder.id);
      await store.replaceTranscript(id, [
        ChatTranscriptTurn(
          role: 'user',
          text: 'hi',
          createdAt: DateTime.utc(2026, 8, 22),
        ),
      ]);
      await store.saveSharedGraph(
        folder.id,
        const ChatEntityGraph(
          nodes: [
            ChatGraphNode(
              id: 'term:queue',
              type: EntityType.term,
              name: 'queue',
            ),
          ],
        ),
      );

      await store.deleteChat(id);

      expect(await store.listChats(), isEmpty);
      expect(
        (await store.loadSharedGraph(folder.id)).nodes.single.name,
        'queue',
      );
    },
  );

  test('IO workspace persists folder membership and shared KV', () async {
    final root = await Directory.systemTemp.createTemp('airo_mind_folders_');
    addTearDown(() => root.delete(recursive: true));
    final store = IoChatWorkspaceStore(root);
    final folder = await store.createFolder('Study');
    final id = await store.createChat(folderId: folder.id);
    await store.saveSharedGraph(
      folder.id,
      const ChatEntityGraph(
        nodes: [
          ChatGraphNode(id: 'term:queue', type: EntityType.term, name: 'queue'),
        ],
      ),
    );

    expect(
      File(
        '${root.path}/${ChatWorkspaceLayout.folderGraphPath(folder.id)}',
      ).existsSync(),
      isTrue,
    );
    final chats = await store.listChats();
    expect(chats.single.folderId, folder.id);
    expect((await store.loadSharedGraph(folder.id)).nodes.single.name, 'queue');

    await store.deleteChat(id);
    expect(await store.listChats(), isEmpty);
    expect(
      Directory(
        '${root.path}/${ChatWorkspaceLayout.chatFolder(id)}',
      ).existsSync(),
      isFalse,
    );
  });

  test('folder plugins persist and survive a chat delete', () async {
    final store = MemoryChatWorkspaceStore();
    final folder = await store.createFolder('Study');
    await store.updateFolder(
      folder.copyWith(pluginIds: const ['draft-diet-plan']),
    );
    final id = await store.createChat(folderId: folder.id);
    await store.deleteChat(id);

    final folders = await store.listFolders();
    expect(folders.single.pluginIds, ['draft-diet-plan']);
  });

  test('IO workspace persists folder plugin ids', () async {
    final root = await Directory.systemTemp.createTemp('airo_mind_plugins_');
    addTearDown(() => root.delete(recursive: true));
    final store = IoChatWorkspaceStore(root);
    final folder = await store.createFolder('Study');
    await store.updateFolder(
      folder.copyWith(pluginIds: const ['lesson-planning-assistant']),
    );

    final reloaded = IoChatWorkspaceStore(root);
    final folders = await reloaded.listFolders();
    expect(folders.single.pluginIds, ['lesson-planning-assistant']);
  });
}
