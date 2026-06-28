import 'package:core_ai/core_ai.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LiteRtLmRuntimeAdapter', () {
    late ActiveModelService activeModelService;

    setUp(() {
      ActiveModelService.resetInstance();
      activeModelService = ActiveModelService.forTesting();
    });

    tearDown(() async {
      await activeModelService.dispose();
      ActiveModelService.resetInstance();
    });

    test('supports LiteRT model packages by extension and tag', () async {
      final adapter = LiteRtLmRuntimeAdapter(
        client: _FakeLiteRtLmClient(hasActiveModel: true),
        activeModelService: activeModelService,
      );

      final supported = await adapter.supportsModel(
        const OfflineModelInfo(
          id: 'gemma-4-e2b-it-litertlm',
          name: 'Gemma 4 E2B',
          family: ModelFamily.gemma,
          fileSizeBytes: 1024,
          downloadUrl: 'https://example.com/gemma-4-e2b-it.litertlm',
          provider: AIProvider.gemma,
          tags: ['litert-lm'],
        ),
      );

      expect(supported, isTrue);
    });

    test('surfaces unsupported tool-calling requests explicitly', () async {
      final adapter = LiteRtLmRuntimeAdapter(
        client: _FakeLiteRtLmClient(hasActiveModel: true),
        activeModelService: activeModelService,
      );

      expect(
        () => adapter.generateText(
          const RuntimeGenerationRequest(
            prompt: 'call a tool',
            requiresToolCalling: true,
          ),
          model: const OfflineModelInfo(
            id: 'gemma-basic',
            name: 'Gemma Basic',
            family: ModelFamily.gemma,
            fileSizeBytes: 1024,
            filePath: '/models/gemma-basic.litertlm',
            provider: AIProvider.gemma,
          ),
        ),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('activates LiteRT as the current runtime after warmup', () async {
      final adapter = LiteRtLmRuntimeAdapter(
        client: _FakeLiteRtLmClient(hasActiveModel: true),
        activeModelService: activeModelService,
        runtimeConfig: const LiteRtLmConfig(modelPath: '/models/gemma.task'),
      );

      final warmed = await adapter.warmupInstalledModel();

      expect(warmed, isTrue);
      expect(
        activeModelService.activeRuntime?.runtimeKind,
        ActiveRuntimeKind.liteRtLm,
      );
      expect(activeModelService.activeRuntime?.runtimeId, 'litert-lm');
    });
  });
}

class _FakeLiteRtLmClient implements LiteRtLmClient {
  _FakeLiteRtLmClient({required this.hasActiveModel});

  bool hasActiveModel;

  @override
  Future<bool> activeModelExists({String? modelPath}) async => hasActiveModel;

  @override
  Future<String> generate({
    required String prompt,
    required LiteRtLmBackend backend,
    required int maxTokens,
    String? systemPrompt,
  }) async => 'ok';

  @override
  Future<void> initialize({
    String? huggingFaceToken,
    String? modelPath,
    LiteRtLmBackend? backend,
    int? maxTokens,
  }) async {}

  @override
  Future<void> installModel({
    required String url,
    required LiteRtLmModelKind modelKind,
    String? huggingFaceToken,
  }) async {
    hasActiveModel = true;
  }
}
