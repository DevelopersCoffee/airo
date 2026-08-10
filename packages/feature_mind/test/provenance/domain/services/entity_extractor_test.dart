import 'package:feature_mind/src/provenance/domain/models/extracted_entity.dart';
import 'package:feature_mind/src/provenance/domain/services/entity_extractor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RuleBasedEntityExtractor', () {
    const extractor = RuleBasedEntityExtractor();

    test('a known discharge-note sentence yields known typed entities', () {
      const text =
          'Dr. Rao prescribed Ibuprofen for the Knee Brace. '
          'Follow-up scheduled for 14 Aug.';

      final entities = extractor.extract(text);

      expect(entities, [
        const ExtractedEntity(text: 'Dr. Rao', type: EntityType.person),
        const ExtractedEntity(text: 'Ibuprofen', type: EntityType.term),
        const ExtractedEntity(text: 'Knee Brace', type: EntityType.term),
        const ExtractedEntity(text: '14 Aug', type: EntityType.date),
      ]);
    });

    test('deduplicates repeated entity text, keeping first-seen order', () {
      final entities = extractor.extract(
        'Ibuprofen taken. Ibuprofen taken again on 14 Aug.',
      );

      expect(entities.map((e) => e.text).toList(), ['Ibuprofen', '14 Aug']);
    });

    test(
      'skips sentence-initial capitalised words to avoid false positives',
      () {
        final entities = extractor.extract('The Ibuprofen dose was increased.');

        expect(entities, [
          const ExtractedEntity(text: 'Ibuprofen', type: EntityType.term),
        ]);
      },
    );

    test('a full name honorific claims its span so it is not split', () {
      final entities = extractor.extract('The visit was with Dr. Okafor.');

      expect(entities, [
        const ExtractedEntity(text: 'Dr. Okafor', type: EntityType.person),
      ]);
    });

    // Non-happy: no entities found.
    test('plain lower-case text with no dates yields no entities', () {
      expect(extractor.extract('the appointment went fine today'), isEmpty);
    });

    // Non-happy: no entities found.
    test('empty or blank text yields no entities', () {
      expect(extractor.extract(''), isEmpty);
      expect(extractor.extract('   '), isEmpty);
    });
  });

  group('EntityExtractionUnavailable', () {
    // Non-happy: extraction unavailable.
    test('carries a human-readable reason distinct from "found nothing"', () {
      const error = EntityExtractionUnavailable();

      expect(error.toString(), contains('unavailable'));
    });

    test('accepts a caller-supplied reason', () {
      const error = EntityExtractionUnavailable('no model loaded');

      expect(error.reason, 'no model loaded');
    });
  });
}
