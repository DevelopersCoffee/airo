import 'package:feature_mind/src/provenance/domain/models/entity_relation.dart';
import 'package:feature_mind/src/provenance/domain/models/extracted_entity.dart';
import 'package:feature_mind/src/provenance/domain/services/entity_relation_extractor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EntityRelationExtractor', () {
    const extractor = EntityRelationExtractor();

    test('the worked NER sentence yields typed relations', () {
      const text =
          'On Aug 29th, 2024, Optimist Corp. announced in Chicago that '
          'its CEO, Brad Doe, would be stepping down after a successful '
          '\$5 million funding round.';

      final graph = extractor.extract(text);

      expect(
        graph.relations,
        unorderedEquals([
          const EntityRelation(
            from: ExtractedEntity(
              text: 'Optimist Corp.',
              type: EntityType.organization,
            ),
            kind: EntityRelationKind.announcedOn,
            to: ExtractedEntity(text: 'Aug 29th, 2024', type: EntityType.date),
          ),
          const EntityRelation(
            from: ExtractedEntity(
              text: 'Optimist Corp.',
              type: EntityType.organization,
            ),
            kind: EntityRelationKind.locatedIn,
            to: ExtractedEntity(text: 'Chicago', type: EntityType.location),
          ),
          const EntityRelation(
            from: ExtractedEntity(
              text: 'Optimist Corp.',
              type: EntityType.organization,
            ),
            kind: EntityRelationKind.valuedAt,
            to: ExtractedEntity(text: '\$5 million', type: EntityType.money),
          ),
          const EntityRelation(
            from: ExtractedEntity(text: 'Brad Doe', type: EntityType.person),
            kind: EntityRelationKind.worksAt,
            to: ExtractedEntity(
              text: 'Optimist Corp.',
              type: EntityType.organization,
            ),
          ),
        ]),
      );
    });

    test('serializes the graph for structured consumers', () {
      final json = extractor
          .extract('Optimist Corp. announced in Chicago.')
          .toJson();

      expect(json['relations'], [
        {
          'from': {
            'text': 'Optimist Corp.',
            'type': 'organization',
            'start': 0,
            'end': 14,
          },
          'kind': 'locatedIn',
          'to': {'text': 'Chicago', 'type': 'location', 'start': 28, 'end': 35},
        },
      ]);
    });

    test('a discharge note with no org yields no relations', () {
      final graph = extractor.extract(
        'Dr. Rao prescribed Ibuprofen for the Knee Brace. '
        'Follow-up scheduled for 14 Aug.',
      );

      expect(graph.entities, isNotEmpty);
      expect(graph.relations, isEmpty);
    });

    test('empty text yields an empty graph', () {
      expect(extractor.extract('').relations, isEmpty);
      expect(extractor.extract('   ').entities, isEmpty);
    });
  });

  group('EntityExtractionPipeline', () {
    test('runs identify, classify, and relate in one pass', () {
      const pipeline = EntityExtractionPipeline();
      final graph = pipeline.run(
        'On Aug 29th, 2024, Optimist Corp. announced in Chicago that '
        'its CEO, Brad Doe, would be stepping down after a successful '
        '\$5 million funding round.',
      );

      expect(graph.entities.toStructuredMap()['person'], ['Brad Doe']);
      expect(graph.relations, isNotEmpty);
      expect(
        graph.relations.map((r) => r.kind),
        containsAll([
          EntityRelationKind.worksAt,
          EntityRelationKind.locatedIn,
          EntityRelationKind.announcedOn,
          EntityRelationKind.valuedAt,
        ]),
      );
    });
  });
}
