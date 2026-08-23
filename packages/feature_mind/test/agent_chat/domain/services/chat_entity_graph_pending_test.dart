import 'package:feature_mind/src/agent_chat/domain/models/chat_entity_graph.dart';
import 'package:feature_mind/src/agent_chat/domain/services/chat_entity_graph_pending.dart';
import 'package:feature_mind/src/agent_chat/domain/services/chat_entity_linker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const linker = ChatEntityLinker();
  final pending = ChatEntityGraphPending();

  test('matches claim pending questions without the word track', () {
    expect(pending.wantsPending("What's pending on my claim?"), isTrue);
    expect(pending.wantsPending('Who is linked to this claim?'), isFalse);
    expect(
      pending.wantsPending("What's pending on my hospital recovery?"),
      isTrue,
    );
    expect(pending.wantsPending("What's pending on my surgery?"), isTrue);
    expect(pending.wantsPending("What's pending on my flat?"), isTrue);
    expect(pending.wantsPending('What is pending on my flat track?'), isTrue);
    expect(pending.wantsPending('What is pending on my RERA?'), isTrue);
    expect(pending.wantsPending('Remind me about groceries'), isFalse);
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

  test(
    'hospital recovery pending lists missing authorization and tests from the graph',
    () {
      final graph = linker.ingest(
        ChatEntityGraph.empty,
        'surgery at City Hospital on 12 Sep',
      );

      final markdown = pending.format(
        graph: graph,
        query: "What's pending on my hospital recovery?",
      );

      expect(markdown, contains('City Hospital'));
      expect(markdown, contains('Not on the graph yet'));
      expect(markdown, contains('Insurance Authorization Reference'));
      expect(markdown, contains('Required Tests List'));
      expect(markdown, contains('Hospital Checklist'));
      expect(markdown, contains('Recovery Notes'));
      expect(markdown.toLowerCase(), isNot(contains('diagnose')));
      expect(markdown.toLowerCase(), isNot(contains('prescribe')));
      expect(markdown, isNot(contains('Settlement outcome')));
    },
  );

  test(
    'hospital pending lists stored tests and auth without clinical advice',
    () {
      final graph = linker.ingest(
        ChatEntityGraph.empty,
        'surgery at City Hospital on 12 Sep, pre-op tests CBC and ECG, '
        'auth ref PREAUTH-44',
      );

      final markdown = pending.format(
        graph: graph,
        query: "What's pending on my hospital recovery?",
      );

      expect(markdown, contains('Required Tests List: CBC and ECG'));
      expect(
        markdown,
        contains('Insurance Authorization Reference: PREAUTH-44'),
      );
      expect(markdown, contains('Hospital Checklist'));
      expect(markdown.toLowerCase(), isNot(contains('ibuprofen')));
    },
  );

  test('flat pending lists missing RERA and builder fields', () {
    final graph = linker.ingest(
      ChatEntityGraph.empty,
      'buying Tower B floor 14',
    );

    final markdown = pending.format(
      graph: graph,
      query: "What's pending on my flat?",
    );

    expect(markdown, contains('Not on the graph yet'));
    expect(markdown, contains('RERA Registration Number'));
    expect(markdown, contains('Builder Track Record Notes'));
    expect(markdown, contains('Promised Amenities List'));
    expect(markdown, contains('Your Target Floor: 14'));
    expect(markdown, isNot(contains('Settlement outcome')));
    expect(markdown.toLowerCase(), isNot(contains('legal advice')));
  });
}
