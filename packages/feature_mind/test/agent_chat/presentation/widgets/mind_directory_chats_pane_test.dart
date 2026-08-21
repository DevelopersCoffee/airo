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
}
