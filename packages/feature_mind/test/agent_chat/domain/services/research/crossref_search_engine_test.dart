import 'package:feature_mind/src/agent_chat/domain/services/research/crossref_search_engine.dart';
import 'package:feature_mind/src/agent_chat/domain/services/research/research_http.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps crossref works to doi urls and titles', () {
    const body = '''
{
  "message": {
    "items": [
      {
        "DOI": "10.1038/nature12373",
        "title": ["Qwen on device"],
        "abstract": "A study of on-device inference.",
        "URL": "https://doi.org/10.1038/nature12373"
      }
    ]
  }
}
''';
    final hits = CrossrefSearchEngine.parseSearchJson(body);
    expect(hits, hasLength(1));
    expect(hits.single.engineId, 'crossref');
    expect(hits.single.title, 'Qwen on device');
    expect(hits.single.url, 'https://doi.org/10.1038/nature12373');
    expect(hits.single.snippet, 'A study of on-device inference.');
  });

  test('falls back to doi.org when crossref omits url', () {
    const body = '''
{
  "message": {
    "items": [
      {
        "DOI": "10.5555/12345",
        "title": ["Fallback paper"]
      }
    ]
  }
}
''';
    final hits = CrossrefSearchEngine.parseSearchJson(body);
    expect(hits.single.url, 'https://doi.org/10.5555/12345');
  });

  test('research http allows crossref api and rejects google', () {
    const client = ResearchHttpClient();
    expect(
      () => client.validate(Uri.parse('https://api.crossref.org/works')),
      returnsNormally,
    );
    expect(
      () => client.get(Uri.parse('https://www.google.com/search?q=qwen')),
      throwsA(isA<ResearchHttpException>()),
    );
  });
}
