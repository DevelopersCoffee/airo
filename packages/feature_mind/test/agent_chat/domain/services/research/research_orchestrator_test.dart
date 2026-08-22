import 'package:feature_mind/src/agent_chat/domain/models/research_event.dart';
import 'package:feature_mind/src/agent_chat/domain/models/research_request.dart';
import 'package:feature_mind/src/agent_chat/domain/services/research/research_orchestrator.dart';
import 'package:feature_mind/src/agent_chat/domain/services/research/research_search.dart';
import 'package:feature_mind/src/agent_chat/domain/services/research/source_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('report cites acquired documents, not search snippets', () async {
    final engine = ResearchOrchestrator(
      engines: [
        _FakeSearchEngine(
          id: 'wikipedia',
          hits: const [
            ResearchHit(
              engineId: 'wikipedia',
              url: 'https://en.wikipedia.org/wiki/Qwen',
              title: 'Qwen',
              snippet: 'SEARCH SNIPPET ONLY',
            ),
          ],
        ),
        _FakeSearchEngine(id: 'arxiv', hits: const []),
      ],
      sourceManager: SourceManager(
        fetcher: (uri) async => _article(
          title: 'Qwen',
          paragraph: 'Qwen is a family of large language models.',
        ),
      ),
    );

    final events = await engine
        .run(
          const ResearchRequest(
            question: 'What is Qwen?',
            mode: ResearchMode.quick,
          ),
        )
        .toList();

    expect(events.last.kind, ResearchEventKind.researchCompleted);
    expect(events.last.detail, contains('https://en.wikipedia.org/wiki/Qwen'));
    expect(events.last.detail, contains('[1]'));
    expect(events.last.detail, contains('Qwen is a family'));
    expect(events.last.detail, isNot(contains('SEARCH SNIPPET ONLY')));
    expect(events.last.detail, isNot(contains('no citations')));
    expect(events.last.detail, contains('## Observability'));
    expect(events.last.detail, contains('Sources used:'));
    expect(events.last.detail, contains('Cost:'));
    expect(
      events.map((event) => event.kind),
      contains(ResearchEventKind.documentParsed),
    );
  });

  test(
    'a second wave runs when the first wave leaves plan nodes uncovered',
    () async {
      var searches = 0;
      final engine = ResearchOrchestrator(
        engines: [
          _CountingEngine(
            id: 'wikipedia',
            onSearch: () => searches++,
            hitsFor: (query) {
              if (query == 'Best offline LLM for Pixel 9') {
                return const [
                  ResearchHit(
                    engineId: 'wikipedia',
                    url: 'https://en.wikipedia.org/wiki/Qwen',
                    title: 'Qwen',
                    snippet: 'A model family.',
                  ),
                ];
              }
              return const [
                ResearchHit(
                  engineId: 'wikipedia',
                  url: 'https://en.wikipedia.org/wiki/Large_language_model',
                  title: 'Large language model',
                  snippet: 'Official overview of LLM documentation themes.',
                ),
              ];
            },
          ),
        ],
        sourceManager: SourceManager(
          fetcher: (uri) async {
            if (uri.path.contains('Large_language_model')) {
              return _article(
                title: 'Large language model',
                paragraph: 'Official overview of LLM documentation themes.',
              );
            }
            return _article(title: 'Qwen', paragraph: 'A model family.');
          },
        ),
      );

      final events = await engine
          .run(
            const ResearchRequest(
              question: 'Best offline LLM for Pixel 9',
              mode: ResearchMode.standard,
            ),
          )
          .toList();

      expect(searches, greaterThan(1));
      expect(
        events.map((event) => event.kind),
        contains(ResearchEventKind.gapDetected),
      );
      expect(events.last.kind, ResearchEventKind.researchCompleted);
      expect(
        events.last.detail,
        contains('https://en.wikipedia.org/wiki/Large_language_model'),
      );
    },
  );

  test('one failed fetch does not crash the research job', () async {
    final engine = ResearchOrchestrator(
      engines: [
        _FakeSearchEngine(
          id: 'wikipedia',
          hits: const [
            ResearchHit(
              engineId: 'wikipedia',
              url: 'https://en.wikipedia.org/wiki/Qwen',
              title: 'Qwen',
              snippet: 'ignore me',
            ),
            ResearchHit(
              engineId: 'wikipedia',
              url: 'https://en.wikipedia.org/wiki/Llama',
              title: 'Llama',
              snippet: 'ignore me too',
            ),
          ],
        ),
      ],
      sourceManager: SourceManager(
        fetcher: (uri) async {
          if (uri.path.contains('Llama')) {
            throw StateError('blocked');
          }
          return _article(
            title: 'Qwen',
            paragraph: 'Acquired after a sibling source failed.',
          );
        },
      ),
    );

    final events = await engine
        .run(
          const ResearchRequest(
            question: 'What is Qwen?',
            mode: ResearchMode.quick,
          ),
        )
        .toList();

    expect(events.last.kind, ResearchEventKind.researchCompleted);
    expect(
      events.map((event) => event.kind),
      contains(ResearchEventKind.sourceRejected),
    );
    expect(
      events.last.detail,
      contains('Acquired after a sibling source failed'),
    );
    expect(events.last.detail, isNot(contains('wiki/Llama')));
  });

  test('empty questions still fail closed', () async {
    final events = await const ResearchOrchestrator(
      engines: [],
    ).run(const ResearchRequest(question: '  ')).toList();
    expect(events.single.kind, ResearchEventKind.researchFailed);
  });

  test(
    'known library urls are skipped so only the delta is acquired',
    () async {
      final fetched = <Uri>[];
      final engine = ResearchOrchestrator(
        engines: [
          _FakeSearchEngine(
            id: 'wikipedia',
            hits: const [
              ResearchHit(
                engineId: 'wikipedia',
                url: 'https://en.wikipedia.org/wiki/Qwen',
                title: 'Qwen',
                snippet: 'old',
              ),
              ResearchHit(
                engineId: 'wikipedia',
                url: 'https://en.wikipedia.org/wiki/Large_language_model',
                title: 'LLM',
                snippet: 'new',
              ),
            ],
          ),
          _FakeSearchEngine(id: 'arxiv', hits: const []),
        ],
        sourceManager: SourceManager(
          fetcher: (uri) async {
            fetched.add(uri);
            return _article(
              title: 'LLM',
              paragraph: 'Large language models are trained on text.',
            );
          },
        ),
      );

      final events = await engine
          .run(
            const ResearchRequest(
              question: 'What is Qwen?',
              mode: ResearchMode.quick,
            ),
            knownSourceUrls: const ['https://en.wikipedia.org/wiki/Qwen'],
          )
          .toList();

      expect(events.last.kind, ResearchEventKind.researchCompleted);
      expect(
        fetched.map((uri) => uri.toString()),
        isNot(contains('https://en.wikipedia.org/wiki/Qwen')),
      );
      expect(events.last.detail, contains('wiki/Large_language_model'));
    },
  );

  test(
    'local-only policy stays authoritative for a restored Private UI',
    () async {
      var searches = 0;
      final engine = ResearchOrchestrator(
        engines: [
          _CountingEngine(
            id: 'wikipedia',
            onSearch: () => searches++,
            hitsFor: (_) => const [],
          ),
        ],
      );

      final events = await engine
          .run(
            const ResearchRequest(
              question: 'Use only local research',
              mode: ResearchMode.quick,
              policy: SearchPolicy.localOnly,
              privacy: PrivacyProfile.private,
            ),
          )
          .toList();

      expect(events.last.kind, ResearchEventKind.researchCompleted);
      expect(searches, 0);
    },
  );
}

String _article({required String title, required String paragraph}) {
  return '<article><h1>$title</h1><p>$paragraph</p></article>';
}

class _FakeSearchEngine implements ResearchSearchEngine {
  const _FakeSearchEngine({required this.id, required this.hits});

  @override
  final String id;
  final List<ResearchHit> hits;

  @override
  Future<List<ResearchHit>> search(String query, {int maxResults = 5}) async {
    if (query.trim().isEmpty) return const [];
    return hits;
  }
}

class _CountingEngine implements ResearchSearchEngine {
  _CountingEngine({
    required this.id,
    required this.onSearch,
    required this.hitsFor,
  });

  @override
  final String id;
  final void Function() onSearch;
  final List<ResearchHit> Function(String query) hitsFor;

  @override
  Future<List<ResearchHit>> search(String query, {int maxResults = 5}) async {
    onSearch();
    return hitsFor(query);
  }
}
