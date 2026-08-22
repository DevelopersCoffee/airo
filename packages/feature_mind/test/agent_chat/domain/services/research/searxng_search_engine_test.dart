import 'package:feature_mind/src/agent_chat/domain/models/research_event.dart';
import 'package:feature_mind/src/agent_chat/domain/models/research_request.dart';
import 'package:feature_mind/src/agent_chat/domain/services/research/research_http.dart';
import 'package:feature_mind/src/agent_chat/domain/services/research/research_orchestrator.dart';
import 'package:feature_mind/src/agent_chat/domain/services/research/research_search.dart';
import 'package:feature_mind/src/agent_chat/domain/services/research/research_service.dart';
import 'package:feature_mind/src/agent_chat/domain/services/research/searxng_search_engine.dart';
import 'package:feature_mind/src/agent_chat/domain/services/research/source_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const body = '''
{
  "results": [
    {
      "url": "https://en.wikipedia.org/wiki/Qwen",
      "title": "Qwen",
      "content": "A <b>family</b> of language models."
    },
    {
      "url": "http://insecure.example/result",
      "title": "Insecure result",
      "content": "Must not become a candidate."
    }
  ]
}
''';

  test('parser maps SearXNG results to untrusted candidate hits', () {
    final hits = SearxngSearchEngine.parseSearchJson(body);

    expect(hits, hasLength(1));
    expect(hits.single.engineId, 'searxng');
    expect(hits.single.url, 'https://en.wikipedia.org/wiki/Qwen');
    expect(hits.single.title, 'Qwen');
    expect(hits.single.snippet, 'A family of language models.');
    expect(hits.single.trustLevel, SourceTrust.untrusted);
  });

  test(
    'large SearXNG JSON remains parseable across the worker boundary',
    () async {
      final padding = List.filled(55 * 1024, 'x').join();
      final largeBody = body.replaceFirst('\n}', ',\n"padding":"$padding"\n}');
      final baseUri = Uri.parse('https://search.home.example/');
      final http = _FakeHttp(baseUri: baseUri, body: largeBody);
      final engine = SearxngSearchEngine(baseUri: baseUri, http: http);

      final hits = await engine.search('Qwen');

      expect(hits, hasLength(1));
      expect(hits.single.trustLevel, SourceTrust.untrusted);
    },
  );

  test('configured client accepts only HTTPS and the configured host', () {
    final baseUri = Uri.parse('https://search.home.example/searx/');
    final engine = SearxngSearchEngine(baseUri: baseUri);

    expect(engine.http.allowedHosts, {'search.home.example'});
    expect(engine.http.allowedOrigins, {baseUri.origin});
    expect(
      ResearchHttpClient.defaultAllowedHosts,
      isNot(contains('search.home.example')),
    );
    expect(
      () =>
          SearxngSearchEngine(baseUri: Uri.parse('http://search.home.example')),
      throwsA(isA<ResearchHttpException>()),
    );
    expect(
      () => const ResearchHttpClient().get(baseUri),
      throwsA(isA<ResearchHttpException>()),
    );
    expect(
      () => engine.http.resolveRedirect(
        baseUri,
        'https://evil.example/redirected',
      ),
      throwsA(isA<ResearchHttpException>()),
    );
    expect(
      engine.http.resolveRedirect(baseUri, '../login').host,
      'search.home.example',
    );
    expect(
      () => engine.http.resolveRedirect(
        baseUri,
        'https://search.home.example:8443/redirected',
      ),
      throwsA(isA<ResearchHttpException>()),
    );
    expect(
      () => LocalResearchService(searxngBaseUri: baseUri),
      returnsNormally,
    );
    expect(
      () => LocalResearchService(
        searxngBaseUri: Uri.parse('http://search.home.example'),
      ),
      throwsA(isA<ResearchHttpException>()),
    );
  });

  test('arbitrary SearXNG candidates do not expand acquisition hosts', () {
    const arbitraryBody = '''
{"results":[{"url":"https://unknown.example/page","title":"Unknown","content":"Candidate"}]}
''';
    final hit = SearxngSearchEngine.parseSearchJson(arbitraryBody).single;

    expect(
      () => const ResearchHttpClient().get(Uri.parse(hit.url)),
      throwsA(isA<ResearchHttpException>()),
    );
  });

  test(
    'Private uses injected SearXNG while source policy owns acquisition',
    () async {
      final baseUri = Uri.parse('https://search.home.example/searx/');
      final http = _FakeHttp(baseUri: baseUri, body: body);
      final orchestrator = ResearchOrchestrator(
        engines: [SearxngSearchEngine(baseUri: baseUri, http: http)],
        sourceManager: SourceManager(
          fetcher: (uri) async {
            expect(uri.host, 'en.wikipedia.org');
            return '<article><h1>Qwen</h1><p>Qwen is a family of language models.</p></article>';
          },
        ),
      );

      final events = await orchestrator
          .run(
            const ResearchRequest(
              question: 'What is Qwen?',
              mode: ResearchMode.quick,
              policy: SearchPolicy.privacyFirst,
              privacy: PrivacyProfile.private,
            ),
          )
          .toList();

      expect(http.requested, isNotEmpty);
      expect(http.requested.single.host, 'search.home.example');
      expect(http.requested.single.path, '/searx/search');
      expect(http.requested.single.queryParameters['format'], 'json');
      expect(events.last.kind, ResearchEventKind.researchCompleted);
      expect(
        SearchRouter.engineIdsFor(PrivacyProfile.private),
        isNot(contains('google')),
      );
    },
  );
}

class _FakeHttp extends ResearchHttpClient {
  _FakeHttp({required this.baseUri, required this.body})
    : super(allowedHosts: {baseUri.host}, allowedOrigins: {baseUri.origin});

  final Uri baseUri;
  final String body;
  final List<Uri> requested = [];

  @override
  Future<String> get(Uri uri) {
    validate(uri);
    requested.add(uri);
    return Future.value(body);
  }
}
