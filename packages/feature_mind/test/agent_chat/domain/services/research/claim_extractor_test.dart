import 'package:feature_mind/src/agent_chat/domain/services/research/claim_extractor.dart';
import 'package:feature_mind/src/agent_chat/domain/services/research/source_classifier.dart';
import 'package:feature_mind/src/agent_chat/domain/services/research/source_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final qwen = SourceDocument(
    url: 'https://en.wikipedia.org/wiki/Qwen',
    title: 'Qwen',
    headings: const ['Qwen'],
    paragraphs: const [
      'Qwen is a family of large language models from Alibaba.',
    ],
    tables: const [],
    codeBlocks: const [],
    retrievedAt: '2026-08-22T00:00:00.000Z',
    classification: const SourceClassification(
      sourceClass: SourceClass.tertiary,
      kind: SourceKind.community,
    ),
  );

  test('each acquired paragraph becomes a claim bound to that source', () {
    final claims = extractClaims([qwen]);

    expect(claims, hasLength(1));
    expect(claims.single.text, contains('Alibaba'));
    expect(claims.single.sourceUrl, qwen.url);
    expect(claims.single.excerpt, qwen.paragraphs.single);
    expect(claims.single.status, ClaimSupport.supported);
  });

  test('acquired table rows become claims bound to that source', () {
    final scored = SourceDocument(
      url: qwen.url,
      title: qwen.title,
      headings: qwen.headings,
      paragraphs: const [],
      tables: const ['Qwen-7B | 64.5 on MMLU'],
      codeBlocks: const [],
      retrievedAt: qwen.retrievedAt,
      classification: qwen.classification,
    );

    final claims = extractClaims([scored]);

    expect(claims, hasLength(1));
    expect(claims.single.text, 'Qwen-7B | 64.5 on MMLU');
    expect(claims.single.sourceUrl, qwen.url);
    expect(claims.single.status, ClaimSupport.supported);
  });

  test(
    'citation validation rejects claims whose source was never acquired',
    () {
      final orphan = ResearchClaim(
        id: 'c-orphan',
        text: 'Invented benchmark numbers.',
        sourceUrl: 'https://seo.example/fake',
        excerpt: 'Invented benchmark numbers.',
        status: ClaimSupport.supported,
      );

      final validated = validateCitations(
        [
          ...extractClaims([qwen]),
          orphan,
        ],
        [qwen],
      );

      expect(
        validated.where((claim) => claim.status == ClaimSupport.supported),
        hasLength(1),
      );
      expect(
        validated.firstWhere((claim) => claim.id == 'c-orphan').status,
        ClaimSupport.unverified,
      );
    },
  );

  test('excerpt that is not in the source document is unverified', () {
    final claims = validateCitations(
      [
        ResearchClaim(
          id: 'c1',
          text: 'Qwen uses 2 GB of RAM.',
          sourceUrl: qwen.url,
          excerpt: 'Qwen uses 2 GB of RAM.',
          status: ClaimSupport.supported,
        ),
      ],
      [qwen],
    );

    expect(claims.single.status, ClaimSupport.unverified);
  });
}
