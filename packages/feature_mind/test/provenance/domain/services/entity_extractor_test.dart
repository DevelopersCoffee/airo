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

    test('the worked NER sentence yields typed structured entities', () {
      const text =
          'On Aug 29th, 2024, Optimist Corp. announced in Chicago that '
          'its CEO, Brad Doe, would be stepping down after a successful '
          '\$5 million funding round.';

      final entities = extractor.extract(text);

      expect(entities, [
        const ExtractedEntity(text: 'Aug 29th, 2024', type: EntityType.date),
        const ExtractedEntity(
          text: 'Optimist Corp.',
          type: EntityType.organization,
        ),
        const ExtractedEntity(text: 'Chicago', type: EntityType.location),
        const ExtractedEntity(text: 'Brad Doe', type: EntityType.person),
        const ExtractedEntity(text: '\$5 million', type: EntityType.money),
      ]);
      expect(entities.toStructuredMap(), {
        'date': ['Aug 29th, 2024'],
        'organization': ['Optimist Corp.'],
        'location': ['Chicago'],
        'person': ['Brad Doe'],
        'money': ['\$5 million'],
      });
    });

    test('records UTF-16 spans for the first date mention', () {
      const text = 'Follow-up scheduled for 14 Aug.';
      final entities = extractor.extract(text);
      final date = entities.singleWhere((e) => e.type == EntityType.date);

      expect(date.text, '14 Aug');
      expect(date.start, text.indexOf('14 Aug'));
      expect(date.end, date.start + date.text.length);
      expect(text.substring(date.start, date.end), date.text);
    });

    test('classifies money, percent, email, and claim identifiers', () {
      final entities = extractor.extract(
        'pay 50% to billing@optimist.example on CLM-1042.',
      );

      expect(entities, [
        const ExtractedEntity(text: '50%', type: EntityType.money),
        const ExtractedEntity(
          text: 'billing@optimist.example',
          type: EntityType.identifier,
        ),
        const ExtractedEntity(text: 'CLM-1042', type: EntityType.identifier),
      ]);
    });

    test('ISO dates and day-month dates with years stay dates', () {
      final entities = extractor.extract(
        'filed on 2024-08-29 after 5th May 2025.',
      );

      expect(entities, [
        const ExtractedEntity(text: '2024-08-29', type: EntityType.date),
        const ExtractedEntity(text: '5th May 2025', type: EntityType.date),
      ]);
    });

    test('serializes extracted entities to JSON with spans', () {
      final json = extractor.extract('Dr. Rao on 14 Aug.').toJson();

      expect(json, [
        {'text': 'Dr. Rao', 'type': 'person', 'start': 0, 'end': 7},
        {'text': '14 Aug', 'type': 'date', 'start': 11, 'end': 17},
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
