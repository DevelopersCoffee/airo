import 'package:feature_mind/src/agent_chat/domain/services/research/research_search.dart';
import 'package:feature_mind/src/agent_chat/domain/services/research/source_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tracking variants collapse to one canonical url', () {
    expect(
      canonicalizeUrl('https://www.example.com/article?utm_source=google'),
      'https://example.com/article',
    );
    expect(
      canonicalizeUrl('http://example.com/article/'),
      'https://example.com/article',
    );
    expect(
      canonicalizeUrl('https://en.wikipedia.org/wiki/Large_language_model'),
      'https://en.wikipedia.org/wiki/Large_language_model',
    );
  });

  test('dedupe keeps the first hit for a canonical url', () {
    final hits = dedupeHits([
      const ResearchHit(
        engineId: 'google',
        url: 'https://www.example.com/article?utm=1',
        title: 'A',
        snippet: 'first',
      ),
      const ResearchHit(
        engineId: 'brave',
        url: 'http://example.com/article/',
        title: 'B',
        snippet: 'second',
      ),
      const ResearchHit(
        engineId: 'arxiv',
        url: 'https://arxiv.org/abs/1234',
        title: 'C',
        snippet: 'paper',
      ),
    ]);

    expect(hits, hasLength(2));
    expect(hits.first.snippet, 'first');
    expect(hits.map((hit) => hit.url), contains('https://arxiv.org/abs/1234'));
  });
}
