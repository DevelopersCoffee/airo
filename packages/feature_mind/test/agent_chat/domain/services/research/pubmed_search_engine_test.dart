import 'package:feature_mind/src/agent_chat/domain/services/research/pubmed_search_engine.dart';
import 'package:feature_mind/src/agent_chat/domain/services/research/research_http.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('esearch parser extracts pmids', () {
    const body = '''
{
  "esearchresult": {
    "count": "2",
    "idlist": ["12345", "67890"]
  }
}
''';
    expect(PubMedSearchEngine.parseEsearchIds(body), ['12345', '67890']);
  });

  test('esummary parser maps pmids to pubmed urls and titles', () {
    const body = '''
{
  "result": {
    "uids": ["12345"],
    "12345": {
      "uid": "12345",
      "title": "Qwen on device",
      "source": "Nature",
      "pubdate": "2024 Jan"
    }
  }
}
''';
    final hits = PubMedSearchEngine.parseEsummaryJson(body);
    expect(hits, hasLength(1));
    expect(hits.single.engineId, 'pubmed');
    expect(hits.single.title, 'Qwen on device');
    expect(hits.single.url, 'https://pubmed.ncbi.nlm.nih.gov/12345/');
    expect(hits.single.snippet, contains('Nature'));
  });

  test('research http allows pubmed eutils and rejects google', () {
    const client = ResearchHttpClient();
    expect(
      () => client.validate(
        Uri.parse(
          'https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi',
        ),
      ),
      returnsNormally,
    );
    expect(
      () => client.get(Uri.parse('https://www.google.com/search?q=qwen')),
      throwsA(isA<ResearchHttpException>()),
    );
  });
}
