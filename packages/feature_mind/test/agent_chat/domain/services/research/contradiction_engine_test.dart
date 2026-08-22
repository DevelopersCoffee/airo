import 'package:feature_mind/src/agent_chat/domain/services/research/claim_extractor.dart';
import 'package:feature_mind/src/agent_chat/domain/services/research/contradiction_engine.dart';
import 'package:feature_mind/src/agent_chat/domain/services/research/source_classifier.dart';
import 'package:feature_mind/src/agent_chat/domain/services/research/source_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('conflicting numeric claims are explained, not silently picked', () {
    const eight = ResearchClaim(
      id: 'c1',
      text: 'Qwen 7B uses 8 GB RAM on a desktop workstation.',
      sourceUrl: 'https://en.wikipedia.org/wiki/Qwen',
      excerpt: 'Qwen 7B uses 8 GB RAM on a desktop workstation.',
      status: ClaimSupport.supported,
    );
    const five = ResearchClaim(
      id: 'c2',
      text: 'Qwen 7B uses 5 GB RAM on Pixel phones.',
      sourceUrl: 'https://arxiv.org/abs/2401.1',
      excerpt: 'Qwen 7B uses 5 GB RAM on Pixel phones.',
      status: ClaimSupport.supported,
    );
    final docs = [
      SourceDocument(
        url: eight.sourceUrl,
        title: 'Qwen',
        headings: const [],
        paragraphs: [eight.text],
        tables: const [],
        codeBlocks: const [],
        retrievedAt: '2026-08-22T00:00:00.000Z',
        publishedAt: '2026-01-15T00:00:00Z',
        classification: const SourceClassification(
          sourceClass: SourceClass.tertiary,
          kind: SourceKind.community,
        ),
      ),
      SourceDocument(
        url: five.sourceUrl,
        title: 'Qwen paper',
        headings: const [],
        paragraphs: [five.text],
        tables: const [],
        codeBlocks: const [],
        retrievedAt: '2026-08-22T00:00:00.000Z',
        publishedAt: '2024-06-01T00:00:00Z',
        classification: const SourceClassification(
          sourceClass: SourceClass.primary,
          kind: SourceKind.academic,
        ),
      ),
    ];

    final conflicts = explainContradictions([eight, five], docs);

    expect(conflicts, hasLength(1));
    expect(conflicts.single.reasons, contains('different result'));
    expect(conflicts.single.reasons, contains('different date'));
    expect(conflicts.single.reasons, contains('different hardware'));
  });

  test('agreeing claims are not flagged as conflicts', () {
    const a = ResearchClaim(
      id: 'c1',
      text: 'Qwen is a family of large language models from Alibaba.',
      sourceUrl: 'https://en.wikipedia.org/wiki/Qwen',
      excerpt: 'Qwen is a family of large language models from Alibaba.',
      status: ClaimSupport.supported,
    );
    const b = ResearchClaim(
      id: 'c2',
      text: 'Qwen is a family of large language models from Alibaba Cloud.',
      sourceUrl: 'https://arxiv.org/abs/2401.1',
      excerpt: 'Qwen is a family of large language models from Alibaba Cloud.',
      status: ClaimSupport.supported,
    );

    expect(explainContradictions([a, b], const []), isEmpty);
  });
}
