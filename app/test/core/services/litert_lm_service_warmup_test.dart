import 'package:airo_app/core/services/litert_lm_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LiteRtLmService.warmupInstalledModel', () {
    test(
      'initializes and performs a private dummy local generation when an installed model exists',
      () async {
        final client = _FakeLiteRtLmClient(activeModelExistsValue: true);
        final service = LiteRtLmService(client: client);

        final warmed = await service.warmupInstalledModel();

        expect(warmed, isTrue);
        expect(client.initializeCalls, 1);
        expect(
          client.installCalls,
          0,
          reason: 'warmup must not download/install models',
        );
        expect(client.generatedPrompts, [' ']);
      },
    );

    test(
      'returns false without installing when no local model exists',
      () async {
        final client = _FakeLiteRtLmClient(activeModelExistsValue: false);
        final service = LiteRtLmService(
          client: client,
          config: const LiteRtLmConfig(
            modelUrl: 'https://example.invalid/model.task',
          ),
        );

        final warmed = await service.warmupInstalledModel();

        expect(warmed, isFalse);
        expect(client.initializeCalls, 0);
        expect(
          client.installCalls,
          0,
          reason: 'warmup must not trigger network model installation',
        );
        expect(client.generatedPrompts, isEmpty);
      },
    );
  });
}

class _FakeLiteRtLmClient implements LiteRtLmClient {
  _FakeLiteRtLmClient({required this.activeModelExistsValue});

  final bool activeModelExistsValue;
  int initializeCalls = 0;
  int installCalls = 0;
  final generatedPrompts = <String>[];
  final initializeModelPaths = <String?>[];

  @override
  Future<bool> activeModelExists({String? modelPath}) async =>
      activeModelExistsValue;

  @override
  Future<void> initialize({
    String? huggingFaceToken,
    String? modelPath,
    LiteRtLmBackend? backend,
    int? maxTokens,
  }) async {
    initializeCalls += 1;
    initializeModelPaths.add(modelPath);
  }

  @override
  Future<void> installModel({
    required String url,
    required LiteRtLmModelKind modelKind,
    String? huggingFaceToken,
  }) async {
    installCalls += 1;
  }

  @override
  Future<String> generate({
    required String prompt,
    required LiteRtLmBackend backend,
    required int maxTokens,
    String? systemPrompt,
  }) async {
    generatedPrompts.add(prompt);
    return '';
  }
}
