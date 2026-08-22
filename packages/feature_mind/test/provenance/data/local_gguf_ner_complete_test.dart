import 'package:core_ai/core_ai.dart';
import 'package:feature_mind/src/agent_chat/data/services/assistant_runtime_service.dart';
import 'package:feature_mind/src/agent_chat/domain/models/assistant_runtime_ids.dart';
import 'package:feature_mind/src/agent_chat/presentation/screens/model_library_screen.dart';
import 'package:feature_mind/src/provenance/data/local_gguf_ner_complete.dart';
import 'package:feature_mind/src/provenance/domain/models/extracted_entity.dart';
import 'package:feature_mind/src/provenance/domain/services/entity_extractor.dart';
import 'package:feature_mind/src/provenance/domain/services/model_entity_extractor.dart';
import 'package:feature_mind/src/runtime/models/model_models.dart';
import 'package:feature_mind/src/runtime/ports/model_port.dart';
import 'package:feature_mind/src/services/gguf_load_outcome.dart';
import 'package:feature_mind/src/services/llama_gguf_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const package = OfflineModelInfo(
    id: 'qwen2-1.5b-q4',
    name: 'Qwen2 1.5B',
    family: ModelFamily.qwen,
    fileSizeBytes: 1_100_000_000,
    filePath: '/models/qwen2-1.5b-q4.gguf',
    provider: AIProvider.gguf,
  );

  const loaded = MindModel(
    id: 'qwen2-1.5b-q4',
    name: 'Qwen2 1.5B',
    sizeBytes: 1,
    residency: ModelResidency.loaded,
  );

  AssistantModelLibraryState libraryFor(OfflineModelInfo model) {
    final runtimeId = assistantModelIdForOfflineModel(model.id);
    final candidate = AssistantModelCandidate(
      id: runtimeId,
      name: model.name,
      runtime: 'GGUF',
      description: 'Installed package',
      bestFor: const [AssistantTask.chat],
      tags: const ['Local'],
      privacyLabel: 'Private',
      sizeLabel: model.fileSizeDisplay,
      available: true,
      actionLabel: 'Start',
      local: true,
      package: model,
    );
    return AssistantModelLibraryState(
      task: AssistantTask.chat,
      deviceLabel: 'Pixel 9',
      platformLabel: 'ANDROID',
      candidates: [candidate],
      recommended: candidate,
      defaultPackages: const {},
    );
  }

  test(
    'production NerComplete passes GBNF grammar to the loaded local GGUF',
    () async {
      final llama = _FakeLlamaGgufService(
        isAvailableResult: true,
        loadModelResult: true,
        generatedChunks: ['[{"text":"sundar pichai","type":"person"}]'],
      );
      var cloudCalled = false;
      final runtime = AssistantRuntimeService(
        llamaGguf: llama,
        generateCloudText: (prompt) async {
          cloudCalled = true;
          return 'remote-ner';
        },
        isCloudAvailable: () => true,
        initializeCloud: () async {},
        loadAssistantModelLibrary: () async => libraryFor(package),
      );
      final extractor = productionModelBackedEntityExtractor(
        models: _CatalogPort(const [loaded]),
        runtime: runtime,
      );

      const text = 'sundar pichai said hello.';
      final entities = await extractor.extract(text);

      expect(cloudCalled, isFalse);
      expect(llama.lastGrammar, ModelBackedEntityExtractor.grammar);
      expect(llama.lastPrompt, contains(text));
      expect(entities, [
        const ExtractedEntity(text: 'sundar pichai', type: EntityType.person),
      ]);
    },
  );

  test('generateText with grammar never calls Gemini Cloud', () async {
    var cloudCalled = false;
    final runtime = AssistantRuntimeService(
      generateCloudText: (prompt) async {
        cloudCalled = true;
        return 'remote-ner';
      },
      isCloudAvailable: () => true,
      initializeCloud: () async {},
    );

    await expectLater(
      runtime.generateText(
        selectedModelId: geminiCloudAssistantModelId,
        prompt: 'extract entities',
        grammar: ModelBackedEntityExtractor.grammar,
      ),
      throwsA(
        isA<AssistantRuntimeUnavailableException>().having(
          (error) => error.message,
          'message',
          constrainedGenerationRequiresLocalGgufMessage,
        ),
      ),
    );
    expect(cloudCalled, isFalse);
  });

  test(
    'complete throws unavailable when ModelPort has no loaded GGUF',
    () async {
      final llama = _FakeLlamaGgufService(
        isAvailableResult: true,
        loadModelResult: true,
        generatedChunks: ['[]'],
      );
      final runtime = AssistantRuntimeService(
        llamaGguf: llama,
        loadAssistantModelLibrary: () async => libraryFor(package),
      );
      final complete = localGgufNerComplete(
        models: _CatalogPort(const []),
        runtime: runtime,
      );

      await expectLater(
        complete(
          prompt: ModelBackedEntityExtractor.promptFor('hello'),
          grammar: ModelBackedEntityExtractor.grammar,
        ),
        throwsA(isA<EntityExtractionUnavailable>()),
      );
      expect(llama.lastGrammar, isNull);
      expect(llama.lastPrompt, isNull);
    },
  );
}

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

class _FakeLlamaGgufService extends LlamaGgufService {
  _FakeLlamaGgufService({
    required this.isAvailableResult,
    this.loadModelResult = false,
    this.generatedChunks = const [],
  });

  final bool isAvailableResult;
  final bool loadModelResult;
  final List<String> generatedChunks;
  String? lastPrompt;
  String? lastGrammar;

  @override
  Future<bool> isAvailable() async => isAvailableResult;

  @override
  Future<bool> loadModel(
    OfflineModelInfo model, {
    int? contextSize,
    int threads = 4,
    int memoryBudgetMb = 4096,
  }) async => loadModelResult;

  @override
  Future<GgufLoadOutcome> loadModelOutcome(
    OfflineModelInfo model, {
    int? contextSize,
    int threads = 4,
    int memoryBudgetMb = 4096,
  }) async {
    return loadModelResult
        ? const GgufLoadOutcome.success()
        : GgufLoadOutcome.engineError('test_load_failed');
  }

  @override
  Stream<String> generate({
    required String prompt,
    int maxTokens = 512,
    double temperature = 0.7,
    double topP = 0.9,
    int topK = 40,
    String? grammar,
  }) {
    lastPrompt = prompt;
    lastGrammar = grammar;
    return Stream<String>.fromIterable(generatedChunks);
  }

  @override
  Future<void> stop() async {}
}
