import 'dart:convert';
import 'dart:io';

import 'package:feature_mind/src/provenance/domain/models/extracted_entity.dart';
import 'package:feature_mind/src/provenance/domain/services/entity_extractor.dart';
import 'package:feature_mind/src/provenance/domain/services/model_entity_extractor.dart';
import 'package:feature_mind/src/runtime/models/model_models.dart';
import 'package:feature_mind/src/runtime/ports/model_port.dart';
import 'package:flutter_test/flutter_test.dart';

class _CatalogPort implements ModelPort {
  @override
  Future<List<MindModel>> all() async => const [
    MindModel(
      id: 'local-gguf',
      name: 'Local GGUF',
      sizeBytes: 1,
      residency: ModelResidency.loaded,
    ),
  ];

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

class _Scores {
  const _Scores({
    required this.precision,
    required this.recall,
    required this.truePositives,
    required this.falsePositives,
    required this.falseNegatives,
  });

  final double precision;
  final double recall;
  final int truePositives;
  final int falsePositives;
  final int falseNegatives;
}

({String text, EntityType type}) _key(ExtractedEntity entity) =>
    (text: entity.text.toLowerCase(), type: entity.type);

_Scores _score({
  required List<ExtractedEntity> predicted,
  required List<ExtractedEntity> gold,
}) {
  final goldKeys = gold.map(_key).toSet();
  final predictedKeys = predicted.map(_key).toSet();
  final tp = predictedKeys.intersection(goldKeys).length;
  final fp = predictedKeys.difference(goldKeys).length;
  final fn = goldKeys.difference(predictedKeys).length;
  return _Scores(
    precision: tp + fp == 0 ? 1 : tp / (tp + fp),
    recall: tp + fn == 0 ? 1 : tp / (tp + fn),
    truePositives: tp,
    falsePositives: fp,
    falseNegatives: fn,
  );
}

List<ExtractedEntity> _goldOf(Map<String, dynamic> example) {
  final raw = example['entities'] as List<dynamic>;
  return [
    for (final item in raw)
      ExtractedEntity(
        text: (item as Map)['text'] as String,
        type: EntityType.values.byName(item['type'] as String),
      ),
  ];
}

void main() {
  final corpusFile = File('test/provenance/fixtures/ner_corpus.json');

  late List<Map<String, dynamic>> corpus;

  setUpAll(() {
    final decoded = jsonDecode(corpusFile.readAsStringSync()) as List<dynamic>;
    corpus = [
      for (final item in decoded) Map<String, dynamic>.from(item as Map),
    ];
  });

  test('rule-based pass scores below 1.0 on lowercase and Indic examples', () {
    const extractor = RuleBasedEntityExtractor();
    final lowercase = corpus.firstWhere(
      (example) => example['id'] == 'sundar-lowercase',
    );
    final indic = corpus.firstWhere(
      (example) => example['id'] == 'indic-hindi',
    );

    expect(
      _score(
        predicted: extractor.extract(lowercase['text'] as String),
        gold: _goldOf(lowercase),
      ).recall,
      lessThan(1),
    );
    expect(
      _score(
        predicted: extractor.extract(indic['text'] as String),
        gold: _goldOf(indic),
      ).recall,
      lessThan(1),
    );
  });

  test(
    'hybrid model pass scores 1.0 precision and recall on the corpus',
    () async {
      final goldByText = {
        for (final example in corpus)
          example['text'] as String: _goldOf(example),
      };
      final extractor = HybridEntityExtractor(
        model: ModelBackedEntityExtractor(
          models: _CatalogPort(),
          complete: ({required prompt, required grammar}) async {
            for (final entry in goldByText.entries) {
              if (prompt.contains(entry.key)) {
                return jsonEncode([
                  for (final entity in entry.value)
                    {'text': entity.text, 'type': entity.type.name},
                ]);
              }
            }
            return '[]';
          },
        ),
      );

      var tp = 0;
      var fp = 0;
      var fn = 0;
      for (final example in corpus) {
        final predicted = await extractor.extract(example['text'] as String);
        final scored = _score(predicted: predicted, gold: _goldOf(example));
        tp += scored.truePositives;
        fp += scored.falsePositives;
        fn += scored.falseNegatives;
      }

      final precision = tp / (tp + fp);
      final recall = tp / (tp + fn);
      expect(precision, 1.0);
      expect(recall, 1.0);
    },
  );
}
