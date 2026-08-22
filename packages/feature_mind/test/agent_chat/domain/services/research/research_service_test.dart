import 'package:feature_mind/src/agent_chat/domain/models/research_event.dart';
import 'package:feature_mind/src/agent_chat/domain/models/research_request.dart';
import 'package:feature_mind/src/agent_chat/domain/services/research/research_library.dart';
import 'package:feature_mind/src/agent_chat/domain/services/research/research_library_log.dart';
import 'package:feature_mind/src/agent_chat/domain/services/research/research_orchestrator.dart';
import 'package:feature_mind/src/agent_chat/domain/services/research/research_search.dart';
import 'package:feature_mind/src/agent_chat/domain/services/research/research_service.dart';
import 'package:feature_mind/src/agent_chat/domain/services/research/source_manager.dart';
import 'package:feature_mind/src/runtime/models/log_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/recording_operation_log.dart';

void main() {
  test(
    'LocalResearchService forwards knownSourceUrls so only the delta is acquired',
    () async {
      final fetched = <Uri>[];
      final ResearchService service = LocalResearchService(
        orchestrator: ResearchOrchestrator(
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
        ),
      );

      final events = await service
          .start(
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
    },
  );

  test(
    'chat library seam reuses prior urls and persists the onLibrary entry',
    () async {
      final log = RecordingOperationLog();
      await appendResearchLibraryOp(
        log: log,
        entry: ResearchLibraryEntry.fromQuestion(
          question: 'What is Qwen?',
          retrievedAt: '2026-08-22T00:00:00Z',
          sourceUrls: const ['https://en.wikipedia.org/wiki/Qwen'],
          findings: const ['Qwen is a family of large language models.'],
        ),
      );

      final known =
          (await latestLibraryEntryFor(log, 'What is Qwen?'))?.sourceUrls ??
          const <String>[];
      expect(known, ['https://en.wikipedia.org/wiki/Qwen']);

      ResearchLibraryEntry? captured;
      final ResearchService service = LocalResearchService(
        orchestrator: ResearchOrchestrator(
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
            fetcher: (uri) async => _article(
              title: 'LLM',
              paragraph: 'Large language models are trained on text.',
            ),
          ),
        ),
      );

      await service
          .start(
            const ResearchRequest(
              question: 'What is Qwen?',
              mode: ResearchMode.quick,
            ),
            knownSourceUrls: known,
            onLibrary: (entry) {
              captured = entry;
            },
          )
          .toList();

      expect(captured, isNotNull);
      expect(
        captured!.sourceUrls,
        contains('https://en.wikipedia.org/wiki/Large_language_model'),
      );
      await appendResearchLibraryOp(log: log, entry: captured!);
      expect(log.appended.last.kind, MindOpKind.researchLibrary);
      expect(
        (await latestLibraryEntryFor(log, 'What is Qwen?'))?.sourceUrls,
        captured!.sourceUrls,
      );
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
