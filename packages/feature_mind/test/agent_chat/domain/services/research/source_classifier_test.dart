import 'package:feature_mind/src/agent_chat/domain/services/research/source_classifier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('arxiv is primary academic, wikipedia is tertiary community', () {
    expect(
      classifySourceUrl('https://arxiv.org/abs/2401.12345'),
      const SourceClassification(
        sourceClass: SourceClass.primary,
        kind: SourceKind.academic,
      ),
    );
    expect(
      classifySourceUrl('https://en.wikipedia.org/wiki/Qwen'),
      const SourceClassification(
        sourceClass: SourceClass.tertiary,
        kind: SourceKind.community,
      ),
    );
    expect(
      classifySourceUrl('https://www.nist.gov/publications/x'),
      const SourceClassification(
        sourceClass: SourceClass.primary,
        kind: SourceKind.government,
      ),
    );
  });
}
