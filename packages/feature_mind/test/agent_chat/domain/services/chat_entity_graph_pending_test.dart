import 'package:feature_mind/src/agent_chat/domain/models/chat_entity_graph.dart';
import 'package:feature_mind/src/agent_chat/domain/services/chat_entity_graph_pending.dart';
import 'package:feature_mind/src/agent_chat/domain/services/chat_entity_linker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const linker = ChatEntityLinker();
  const pending = ChatEntityGraphPending();

  test('matches claim pending questions without the word track', () {
    expect(pending.wantsPending("What's pending on my claim?"), isTrue);
    expect(pending.wantsPending('Who is linked to this claim?'), isFalse);
    expect(pending.wantsPending('What is pending on my flat track?'), isFalse);
  });

  test('lists stored claim facts and usual fields still absent', () {
    final graph = linker.ingest(
      ChatEntityGraph.empty,
      'Niva Bupa reimbursement Claim ID 9001001 via Policybazaar. '
      'All documents received after surgery at City Hospital.',
    );

    final markdown = pending.format(
      graph: graph,
      query: "What's pending on my claim?",
    );

    expect(markdown, contains('Stored for Niva Bupa claim 9001001'));
    expect(markdown, contains('Insurer: Niva Bupa'));
    expect(markdown, contains('Documents: received'));
    expect(markdown, contains('Not on the graph yet'));
    expect(markdown, contains('Settlement outcome'));
    expect(markdown, contains('Policy number'));
    expect(markdown, isNot(contains('Claim documents (not marked received)')));
    expect(markdown, contains('Also linked'));
    expect(markdown, contains('City Hospital'));
  });

  test('marks documents as missing when they were never received', () {
    final graph = linker.ingest(
      ChatEntityGraph.empty,
      'Star Insurance Claim ID 111222',
    );

    final markdown = pending.format(
      graph: graph,
      query: 'What is pending on my claim?',
    );

    expect(markdown, contains('Claim documents (not marked received)'));
    expect(markdown, isNot(contains('Documents: received')));
  });
}
