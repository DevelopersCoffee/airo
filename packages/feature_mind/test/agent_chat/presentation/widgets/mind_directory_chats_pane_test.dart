import 'package:feature_mind/src/agent_chat/domain/models/chat_entity_graph.dart';
import 'package:feature_mind/src/agent_chat/domain/models/chat_transcript_turn.dart';
import 'package:feature_mind/src/agent_chat/presentation/widgets/mind_directory_chats_pane.dart';
import 'package:feature_mind/src/provenance/domain/models/extracted_entity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('groups entities as a directory and lists chats', (tester) async {
    const graph = ChatEntityGraph(
      nodes: [
        ChatGraphNode(
          id: 'organization:niva-bupa',
          type: EntityType.organization,
          name: 'Niva Bupa',
        ),
        ChatGraphNode(
          id: 'identifier:9001001',
          type: EntityType.identifier,
          name: 'Claim 9001001',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MindDirectoryChatsPane(
            directory: graph,
            chats: [
              MindChatRecord(
                id: 'chat-1',
                title: 'Niva Bupa Claim ID 9001001',
                updatedAt: DateTime.utc(2026, 8, 21),
                preview: 'All documents received',
              ),
            ],
            activeChatId: 'chat-1',
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('mind.directory.chats.pane')), findsOneWidget);
    expect(find.text('DIRECTORY'), findsOneWidget);
    expect(find.text('organizations'), findsOneWidget);
    expect(find.text('Niva Bupa'), findsOneWidget);
    expect(find.text('CHATS'), findsOneWidget);
    expect(find.text('Niva Bupa Claim ID 9001001'), findsOneWidget);
  });

  testWidgets('groups chats under a named folder', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MindDirectoryChatsPane(
            directory: ChatEntityGraph.empty,
            folders: const [MindChatFolder(id: 'study', name: 'Study')],
            chats: [
              MindChatRecord(
                id: 'chat-1',
                title: 'Morning routine',
                updatedAt: DateTime.utc(2026, 8, 22),
                folderId: 'study',
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('mind.chats.folder.study')), findsOneWidget);
    expect(find.text('Study'), findsOneWidget);
    expect(find.text('Shared knowledge'), findsOneWidget);
    expect(find.text('Morning routine'), findsOneWidget);
  });

  testWidgets('new chat under a folder calls onNewChatInFolder', (
    tester,
  ) async {
    String? createdIn;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MindDirectoryChatsPane(
            directory: ChatEntityGraph.empty,
            folders: const [MindChatFolder(id: 'study', name: 'Study')],
            chats: const [],
            onNewChatInFolder: (id) => createdIn = id,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('mind.chats.folder.study.new')));
    await tester.pumpAndSettle();
    expect(createdIn, 'study');
  });

  testWidgets('dropping a chat on a folder moves it', (tester) async {
    String? movedChat;
    String? movedFolder;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 800,
            child: MindDirectoryChatsPane(
              directory: ChatEntityGraph.empty,
              folders: const [MindChatFolder(id: 'study', name: 'Study')],
              chats: [
                MindChatRecord(
                  id: 'chat-1',
                  title: 'Unfiled chat',
                  updatedAt: DateTime.utc(2026, 8, 22),
                ),
              ],
              onMoveChat: (chatId, folderId) {
                movedChat = chatId;
                movedFolder = folderId;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final chat = tester.getCenter(
      find.byKey(const Key('mind.chats.row.chat-1')),
    );
    final folder = tester.getCenter(
      find.byKey(const Key('mind.chats.folder.study.drop')),
    );
    final gesture = await tester.startGesture(chat);
    await tester.pump();
    await gesture.moveTo(folder);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(movedChat, 'chat-1');
    expect(movedFolder, 'study');
  });

  testWidgets('folder plugin dialog saves attached plugins', (tester) async {
    List<String>? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MindDirectoryChatsPane(
            directory: ChatEntityGraph.empty,
            folders: const [MindChatFolder(id: 'study', name: 'Study')],
            chats: const [],
            pluginOptions: const [
              MindFolderPluginOption(
                id: 'draft-diet-plan',
                name: 'Draft diet plan',
                description: 'Meal plans on device',
              ),
            ],
            onSetFolderPlugins: (folderId, pluginIds) => saved = pluginIds,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('mind.chats.folder.study.plugins')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('mind.chats.folder.study.plugin.draft-diet-plan')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('mind.chats.folder.study.plugins.save')),
    );
    await tester.pumpAndSettle();
    expect(saved, ['draft-diet-plan']);
  });

  testWidgets('remove chat asks before deleting', (tester) async {
    final removed = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MindDirectoryChatsPane(
            directory: ChatEntityGraph.empty,
            chats: [
              MindChatRecord(
                id: 'chat-1',
                title: 'hi',
                updatedAt: DateTime.utc(2026, 8, 22),
              ),
            ],
            onRemoveChat: removed.add,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('mind.chats.row.menu.chat-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove chat'));
    await tester.pumpAndSettle();
    expect(find.text('Remove this chat?'), findsOneWidget);

    await tester.tap(find.byKey(const Key('mind.chats.remove.cancel')));
    await tester.pumpAndSettle();
    expect(removed, isEmpty);

    await tester.tap(find.byKey(const Key('mind.chats.row.menu.chat-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove chat'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mind.chats.remove.confirm')));
    await tester.pumpAndSettle();
    expect(removed, ['chat-1']);
  });
}
