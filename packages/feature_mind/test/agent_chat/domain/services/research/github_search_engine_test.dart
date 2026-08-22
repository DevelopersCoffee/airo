import 'package:feature_mind/src/agent_chat/domain/services/research/github_search_engine.dart';
import 'package:feature_mind/src/agent_chat/domain/services/research/research_http.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps repository search results to hits', () {
    const body = '''
{
  "items": [
    {
      "html_url": "https://github.com/qwenlm/Qwen",
      "full_name": "qwenlm/Qwen",
      "description": "The official repo of Qwen."
    }
  ]
}
''';
    final hits = GitHubSearchEngine.parseSearchJson(body);
    expect(hits, hasLength(1));
    expect(hits.single.engineId, 'github');
    expect(hits.single.url, 'https://github.com/qwenlm/Qwen');
    expect(hits.single.title, 'qwenlm/Qwen');
    expect(hits.single.snippet, 'The official repo of Qwen.');
  });

  test('rejects credential-bearing repository urls', () {
    const body = '''
{
  "items": [
    {
      "html_url": "https://user:secret@github.com/org/repo",
      "full_name": "org/repo",
      "description": "bad"
    }
  ]
}
''';
    expect(GitHubSearchEngine.parseSearchJson(body), isEmpty);
  });

  test('research http allows the github api host and rejects google', () {
    const client = ResearchHttpClient();
    expect(
      () => client.validate(
        Uri.parse('https://api.github.com/search/repositories'),
      ),
      returnsNormally,
    );
    expect(
      () => client.get(Uri.parse('https://www.google.com/search?q=qwen')),
      throwsA(isA<ResearchHttpException>()),
    );
  });
}
