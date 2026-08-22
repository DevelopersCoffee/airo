import 'package:feature_mind/src/provenance/domain/models/extracted_entity.dart';
import 'package:feature_mind/src/provenance/domain/services/entity_extractor.dart';
import 'package:feature_mind/src/provenance/domain/services/entity_relation_extractor.dart';
import 'package:feature_mind/src/provenance/domain/services/model_entity_extractor.dart';
import 'package:feature_mind/src/runtime/models/model_models.dart';
import 'package:feature_mind/src/runtime/ports/model_port.dart';
import 'package:flutter_test/flutter_test.dart';

class _CatalogPort implements ModelPort {
  _CatalogPort(this._models);

  final List<MindModel> _models;

  @override
  Future<List<MindModel>> all() async => _models;

  @override
  Future<ModelBench> benchmark(String modelId) async =>
      throw UnimplementedError();

  @override
  Stream<({int received, int total})> download(String modelId) =>
      const Stream.empty();

  @override
  Future<void> load(String modelId) async {}

  @override
  Future<({int budgetBytes, int usedBytes})> storage() async =>
      (usedBytes: 0, budgetBytes: 1);

  @override
  Stream<ThermalState> thermal() => const Stream.empty();

  @override
  Future<void> unload(String modelId) async {}
}

const _loaded = MindModel(
  id: 'local-gguf',
  name: 'Local GGUF',
  sizeBytes: 1,
  residency: ModelResidency.loaded,
);

const _diskOnly = MindModel(
  id: 'local-gguf',
  name: 'Local GGUF',
  sizeBytes: 1,
  residency: ModelResidency.available,
);

void main() {
  group('ModelBackedEntityExtractor', () {
    test('throws EntityExtractionUnavailable when no GGUF is loaded', () async {
      final extractor = ModelBackedEntityExtractor(
        models: _CatalogPort(const [_diskOnly]),
        complete: ({required prompt, required grammar}) async => '[]',
      );

      await expectLater(
        extractor.extract('sundar pichai joined Google.'),
        throwsA(
          isA<EntityExtractionUnavailable>().having(
            (error) => error.reason,
            'reason',
            contains('no model loaded'),
          ),
        ),
      );
    });

    test('throws when the catalog is empty', () async {
      final extractor = ModelBackedEntityExtractor(
        models: _CatalogPort(const []),
        complete: ({required prompt, required grammar}) async => '[]',
      );

      await expectLater(
        extractor.extract('sundar pichai joined Google.'),
        throwsA(isA<EntityExtractionUnavailable>()),
      );
    });

    test('does not call generate when nothing is loaded', () async {
      var called = false;
      final extractor = ModelBackedEntityExtractor(
        models: _CatalogPort(const []),
        complete: ({required prompt, required grammar}) async {
          called = true;
          return '[]';
        },
      );

      await expectLater(
        extractor.extract('hello'),
        throwsA(isA<EntityExtractionUnavailable>()),
      );
      expect(called, isFalse);
    });

    test('parses loaded-model JSON into source-aligned spans', () async {
      late String seenPrompt;
      late String seenGrammar;
      final extractor = ModelBackedEntityExtractor(
        models: _CatalogPort(const [_loaded]),
        complete: ({required prompt, required grammar}) async {
          seenPrompt = prompt;
          seenGrammar = grammar;
          return '[{"text":"sundar pichai","type":"person"}]';
        },
      );

      const text = 'sundar pichai joined the board.';
      final entities = await extractor.extract(text);

      expect(seenPrompt, contains(text));
      expect(seenGrammar, contains('root ::='));
      expect(entities, [
        const ExtractedEntity(text: 'sundar pichai', type: EntityType.person),
      ]);
      expect(
        text.substring(entities.single.start, entities.single.end),
        'sundar pichai',
      );
    });

    test('drops hallucinated mentions that are not in the source', () async {
      final extractor = ModelBackedEntityExtractor(
        models: _CatalogPort(const [_loaded]),
        complete: ({required prompt, required grammar}) async =>
            '[{"text":"Sundar Pichai","type":"person"},'
            '{"text":"invented entity","type":"organization"}]',
      );

      final entities = await extractor.extract(
        'sundar pichai joined the board.',
      );

      expect(entities, isEmpty);
    });

    test('empty text yields nothing without calling generate', () async {
      var called = false;
      final extractor = ModelBackedEntityExtractor(
        models: _CatalogPort(const [_loaded]),
        complete: ({required prompt, required grammar}) async {
          called = true;
          return '[]';
        },
      );

      expect(await extractor.extract('   '), isEmpty);
      expect(called, isFalse);
    });
  });

  group('HybridEntityExtractor', () {
    test('falls back to rules when no model is loaded', () async {
      final extractor = HybridEntityExtractor(
        model: ModelBackedEntityExtractor(
          models: _CatalogPort(const []),
          complete: ({required prompt, required grammar}) async => '[]',
        ),
      );

      final entities = await extractor.extract(
        'Dr. Rao prescribed Ibuprofen on 14 Aug.',
      );

      expect(
        entities.map((e) => e.text),
        containsAll(['Dr. Rao', 'Ibuprofen', '14 Aug']),
      );
    });

    test('keeps rule money and dates when the model disagrees', () async {
      final extractor = HybridEntityExtractor(
        model: ModelBackedEntityExtractor(
          models: _CatalogPort(const [_loaded]),
          complete: ({required prompt, required grammar}) async =>
              '[{"text":"\$5 million","type":"organization"},'
              '{"text":"14 Aug","type":"person"}]',
        ),
      );

      final entities = await extractor.extract('paid \$5 million on 14 Aug.');

      expect(
        entities,
        containsAll([
          const ExtractedEntity(text: '\$5 million', type: EntityType.money),
          const ExtractedEntity(text: '14 Aug', type: EntityType.date),
        ]),
      );
    });

    test('types uncapitalised names the rules miss', () async {
      final extractor = HybridEntityExtractor(
        model: ModelBackedEntityExtractor(
          models: _CatalogPort(const [_loaded]),
          complete: ({required prompt, required grammar}) async =>
              '[{"text":"sundar pichai","type":"person"},'
              '{"text":"google cloud","type":"product"},'
              '{"text":"olympic games","type":"event"}]',
        ),
      );

      final entities = await extractor.extract(
        'sundar pichai said google cloud ships before the olympic games.',
      );

      expect(
        entities,
        containsAll([
          const ExtractedEntity(text: 'sundar pichai', type: EntityType.person),
          const ExtractedEntity(text: 'google cloud', type: EntityType.product),
          const ExtractedEntity(text: 'olympic games', type: EntityType.event),
        ]),
      );
    });

    test(
      'types Indic names the Latin capitalisation pass cannot see',
      () async {
        final extractor = HybridEntityExtractor(
          model: ModelBackedEntityExtractor(
            models: _CatalogPort(const [_loaded]),
            complete: ({required prompt, required grammar}) async =>
                '[{"text":"सुंदर पिचाई","type":"person"}]',
          ),
        );

        final entities = await extractor.extract(
          'सुंदर पिचाई ने गूगल क्लाउड की घोषणा की।',
        );

        expect(entities, [
          const ExtractedEntity(text: 'सुंदर पिचाई', type: EntityType.person),
        ]);
      },
    );

    test('disambiguates Washington as a place vs a person', () async {
      final extractor = HybridEntityExtractor(
        model: ModelBackedEntityExtractor(
          models: _CatalogPort(const [_loaded]),
          complete: ({required prompt, required grammar}) async {
            if (prompt.contains('landed in Washington')) {
              return '[{"text":"Washington","type":"location"}]';
            }
            return '[{"text":"Washington","type":"person"}]';
          },
        ),
      );

      final place = await extractor.extract(
        'The flight landed in Washington after midnight.',
      );
      final person = await extractor.extract(
        'Washington signed the bill on 14 Aug.',
      );

      expect(
        place.singleWhere((e) => e.text == 'Washington').type,
        EntityType.location,
      );
      expect(
        person.singleWhere((e) => e.text == 'Washington').type,
        EntityType.person,
      );
    });

    test('disambiguates Apple as an organization', () async {
      final extractor = HybridEntityExtractor(
        model: ModelBackedEntityExtractor(
          models: _CatalogPort(const [_loaded]),
          complete: ({required prompt, required grammar}) async =>
              '[{"text":"Apple","type":"organization"}]',
        ),
      );

      final entities = await extractor.extract(
        'Apple announced a \$5 million round in Chicago.',
      );

      expect(
        entities,
        contains(
          const ExtractedEntity(text: 'Apple', type: EntityType.organization),
        ),
      );
      expect(
        entities,
        contains(
          const ExtractedEntity(text: '\$5 million', type: EntityType.money),
        ),
      );
    });
  });

  group('EntityExtractionPipeline', () {
    test('run stays rule-based when no model is attached', () {
      const pipeline = EntityExtractionPipeline();
      final graph = pipeline.run(
        'sundar pichai said google cloud ships before the olympic games.',
      );

      expect(graph.entities, isEmpty);
    });

    test('runEnriched fills lowercase mentions through the model', () async {
      final pipeline = EntityExtractionPipeline(
        model: ModelBackedEntityExtractor(
          models: _CatalogPort(const [_loaded]),
          complete: ({required prompt, required grammar}) async =>
              '[{"text":"sundar pichai","type":"person"}]',
        ),
      );

      final graph = await pipeline.runEnriched('sundar pichai said hello.');

      expect(graph.entities, [
        const ExtractedEntity(text: 'sundar pichai', type: EntityType.person),
      ]);
    });
  });
}
