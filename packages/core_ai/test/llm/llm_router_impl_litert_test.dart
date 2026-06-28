import 'package:core_ai/core_ai.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LLMRouterImpl LiteRT routing', () {
    late ActiveModelService activeModelService;

    setUp(() {
      ActiveModelService.resetInstance();
      activeModelService = ActiveModelService.forTesting();
    });

    tearDown(() async {
      await activeModelService.dispose();
      ActiveModelService.resetInstance();
    });

    test('selects LiteRT adapter for compatible local packages', () async {
      final adapter = LiteRtLmRuntimeAdapter(
        client: _FakeLiteRtLmClient(hasActiveModel: true),
        activeModelService: activeModelService,
        runtimeConfig: const LiteRtLmConfig(
          modelPath: '/models/gemma.litertlm',
        ),
      );
      final router = LLMRouterImpl(
        liteRtLmAdapter: adapter,
        activeModelService: activeModelService,
      );

      final client = await router.routeForOfflineModel(
        model: const OfflineModelInfo(
          id: 'gemma-4-e2b-it-litertlm',
          name: 'Gemma 4 E2B',
          family: ModelFamily.gemma,
          fileSizeBytes: 1024,
          filePath: '/models/gemma-4-e2b-it.litertlm',
          provider: AIProvider.gemma,
          supportsVision: true,
        ),
        request: const RuntimeGenerationRequest(
          prompt: 'Describe this receipt',
          localOnly: true,
        ),
      );

      expect(client, same(adapter));
    });

    test(
      'fails explicitly when local-only LiteRT routing is unavailable',
      () async {
        final adapter = LiteRtLmRuntimeAdapter(
          client: _FakeLiteRtLmClient(hasActiveModel: false),
          activeModelService: activeModelService,
        );
        final router = LLMRouterImpl(
          liteRtLmAdapter: adapter,
          activeModelService: activeModelService,
        );

        expect(
          () => router.routeForOfflineModel(
            model: const OfflineModelInfo(
              id: 'gemma-4-e2b-it-litertlm',
              name: 'Gemma 4 E2B',
              family: ModelFamily.gemma,
              fileSizeBytes: 1024,
              filePath: '/models/gemma-4-e2b-it.litertlm',
              provider: AIProvider.gemma,
            ),
            request: const RuntimeGenerationRequest(
              prompt: 'hello',
              localOnly: true,
            ),
          ),
          throwsA(isA<StateError>()),
        );
      },
    );
  });
}

class _FakeLiteRtLmClient implements LiteRtLmClient {
  _FakeLiteRtLmClient({required this.hasActiveModel});

  final bool hasActiveModel;

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
  }) async {}
}
