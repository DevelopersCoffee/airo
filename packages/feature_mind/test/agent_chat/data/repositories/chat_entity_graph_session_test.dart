import 'package:feature_mind/src/agent_chat/data/repositories/chat_entity_graph_session.dart';
import 'package:feature_mind/src/agent_chat/domain/models/chat_entity_graph.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ephemeral graphs are partitioned per conversation', () async {
    final session = ChatEntityGraphSession();
    session.bindConversation('chat-a');
    await session.ingest('Niva claim ABC123 for reimbursement');
    session.bindConversation('chat-b');
    final other = await session.ensureLoaded();
    expect(other.nodes, isEmpty);

    session.bindConversation('chat-a');
    expect(session.graph.nodes, isNotEmpty);
  });

  test('ephemeral slots expire after ttl', () async {
  var now = DateTime.utc(2026, 8, 22, 12);
    final session = ChatEntityGraphSession(
      ephemeralTtl: const Duration(hours: 1),
      now: () => now,
    );
    session.bindConversation('chat-expire');
    await session.ingest('Niva claim ABC123');
    expect(session.graph.nodes, isNotEmpty);

    now = now.add(const Duration(hours: 2));
    session.bindConversation('chat-expire');
    final graph = await session.ensureLoaded();
    expect(graph.nodes, isEmpty);
  });

  test('invalidate clears all ephemeral slots', () async {
    final session = ChatEntityGraphSession();
    session.bindConversation('chat-clear');
    await session.ingest('Niva claim ABC123');
    session.invalidateAllEphemeralGraphs();
    session.bindConversation('chat-clear');
    final graph = await session.ensureLoaded();
    expect(graph, ChatEntityGraph.empty);
  });
}
