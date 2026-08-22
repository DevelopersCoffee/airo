import 'package:feature_mind/src/agent_chat/domain/services/research/research_http.dart';
import 'package:feature_mind/src/agent_chat/domain/services/research/wikipedia_search_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('wikipedia parser maps search titles to wiki urls', () {
    const body = '''
{"query":{"search":[{"title":"Qwen","snippet":"A family of LLMs","pageid":1}]}}
''';
    final hits = WikipediaSearchEngine.parseSearchJson(body);
    expect(hits, hasLength(1));
    expect(hits.single.url, 'https://en.wikipedia.org/wiki/Qwen');
    expect(hits.single.title, 'Qwen');
    expect(hits.single.engineId, 'wikipedia');
  });

  test('research http client rejects non-https and unknown hosts', () async {
    const client = ResearchHttpClient();
    expect(
      () => client.get(Uri.parse('http://en.wikipedia.org/w/api.php')),
      throwsA(isA<ResearchHttpException>()),
    );
    expect(
      () => client.get(Uri.parse('https://evil.example/w/api.php')),
      throwsA(isA<ResearchHttpException>()),
    );
  });
}
