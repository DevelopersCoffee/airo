import 'package:feature_mind/src/agent_chat/domain/services/research/local_memory_search_engine.dart';
import 'package:feature_mind/src/agent_chat/domain/services/research/research_library.dart';
import 'package:feature_mind/src/agent_chat/domain/services/research/research_library_log.dart';
import 'package:feature_mind/src/runtime/models/log_models.dart';
import '../../../../support/recording_operation_log.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('matches prior library entries by topic key', () {
    final hits = LocalMemorySearchEngine.hitsFor(
      query: 'What is Qwen?',
      entries: [
        ResearchLibraryEntry.fromQuestion(
          question: 'What is Qwen?',
          retrievedAt: '2026-08-22T00:00:00Z',
          sourceUrls: const ['https://en.wikipedia.org/wiki/Qwen'],
          findings: const ['Qwen is a family of large language models.'],
        ),
        ResearchLibraryEntry.fromQuestion(
          question: 'Pixel 9 battery life',
          retrievedAt: '2026-08-22T01:00:00Z',
          sourceUrls: const ['https://example.com/pixel'],
          findings: const ['All-day battery.'],
        ),
      ],
    );
    expect(hits, hasLength(1));
    expect(hits.single.engineId, 'local_memory');
    expect(hits.single.url, 'https://en.wikipedia.org/wiki/Qwen');
    expect(hits.single.snippet, contains('family of large language models'));
  });

  test('skips library entries without acquirable source urls', () {
    final hits = LocalMemorySearchEngine.hitsFor(
      query: 'orphan topic',
      entries: [
        ResearchLibraryEntry.fromQuestion(
          question: 'orphan topic',
          retrievedAt: '2026-08-22T00:00:00Z',
          sourceUrls: const [],
          findings: const ['Finding without a url.'],
        ),
      ],
    );
    expect(hits, isEmpty);
  });

  test('loads matching entries from the operation log', () async {
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
    final engine = LocalMemorySearchEngine(operationLog: log);
    final hits = await engine.search('What is Qwen?');
    expect(hits, hasLength(1));
    expect(hits.single.engineId, 'local_memory');
  });
}
