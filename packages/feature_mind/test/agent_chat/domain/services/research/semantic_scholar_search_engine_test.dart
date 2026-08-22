import 'package:feature_mind/src/agent_chat/domain/services/research/research_http.dart';
import 'package:feature_mind/src/agent_chat/domain/services/research/semantic_scholar_search_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('prefers an arxiv abs url when the paper has an arxiv id', () {
    const body = '''
{"data":[{"paperId":"abc","title":"Qwen2","abstract":"A language model.","url":"https://www.semanticscholar.org/paper/abc","externalIds":{"ArXiv":"2407.10671"}}]}
''';
    final hits = SemanticScholarSearchEngine.parseSearchJson(body);
    expect(hits, hasLength(1));
    expect(hits.single.engineId, 'semantic_scholar');
    expect(hits.single.title, 'Qwen2');
    expect(hits.single.url, 'https://arxiv.org/abs/2407.10671');
    expect(hits.single.snippet, 'A language model.');
  });

  test('falls back to the scholar url when no acquirable paper id exists', () {
    const body = '''
{"data":[{"paperId":"xyz","title":"Survey","abstract":null,"url":"https://www.semanticscholar.org/paper/xyz"}]}
''';
    final hits = SemanticScholarSearchEngine.parseSearchJson(body);
    expect(hits.single.url, 'https://www.semanticscholar.org/paper/xyz');
  });

  test(
    'research http allows the scholar api host and still rejects google',
    () {
      const client = ResearchHttpClient();
      expect(
        () => client.validate(
          Uri.parse('https://api.semanticscholar.org/graph/v1/paper/search'),
        ),
        returnsNormally,
      );
      expect(
        () => client.get(Uri.parse('https://www.google.com/search?q=qwen')),
        throwsA(isA<ResearchHttpException>()),
      );
    },
  );
}
