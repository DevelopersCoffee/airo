import 'package:feature_mind/src/agent_chat/domain/services/research/research_search.dart';
import 'package:feature_mind/src/agent_chat/domain/services/research/source_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const hit = ResearchHit(
    engineId: 'wikipedia',
    url: 'https://en.wikipedia.org/wiki/Qwen',
    title: 'Qwen',
    snippet: 'SEARCH SNIPPET ONLY — not evidence',
  );

  test('search hits are not evidence until the page is acquired', () async {
    final fetches = <Uri>[];
    final manager = SourceManager(
      fetcher: (uri) async {
        fetches.add(uri);
        return '''
<article>
  <h1>Qwen</h1>
  <p>Qwen is a family of large language models from Alibaba.</p>
</article>
''';
      },
      now: () => DateTime.utc(2026, 8, 22),
    );

    final first = await manager.acquire(hit);
    final second = await manager.acquire(hit);

    expect(first.document, isNotNull);
    expect(first.document!.evidenceText, contains('Alibaba'));
    expect(first.document!.evidenceText, isNot(contains('SEARCH SNIPPET')));
    expect(first.document!.retrievedAt, '2026-08-22T00:00:00.000Z');
    expect(fetches, hasLength(1), reason: 'same URL must be cached');
    expect(second.document!.url, first.document!.url);
  });

  test('pdf bytes are extracted as evidence, not treated as html', () async {
    const pdfHit = ResearchHit(
      engineId: 'arxiv',
      url: 'https://arxiv.org/pdf/2401.12345',
      title: 'Qwen paper',
      snippet: 'SEARCH SNIPPET ONLY',
    );
    final manager = SourceManager(
      fetcher: (uri) async =>
          '%PDF-1.1\nBT (Qwen is a family of language models) Tj ET\n%%EOF\n',
      now: () => DateTime.utc(2026, 8, 22),
    );

    final result = await manager.acquire(pdfHit);

    expect(result.document, isNotNull);
    expect(result.document!.evidenceText, contains('language models'));
    expect(result.document!.evidenceText, isNot(contains('SEARCH SNIPPET')));
    expect(
      result.document!.evidenceText.toLowerCase(),
      isNot(contains('%pdf')),
    );
  });

  test('a failed fetch rejects the source and does not throw', () async {
    final manager = SourceManager(
      fetcher: (uri) async => throw StateError('blocked'),
    );

    final result = await manager.acquire(hit);

    expect(result.document, isNull);
    expect(result.rejection, contains('blocked'));
  });
}
