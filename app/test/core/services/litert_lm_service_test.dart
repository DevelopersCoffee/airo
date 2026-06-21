import 'package:airo_app/core/services/litert_lm_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LiteRtLmService', () {
    test('reports unavailable when no active model or model URL exists', () async {
      final client = _FakeLiteRtLmClient(hasActiveModel: false);
      final service = LiteRtLmService(client: client);

      final available = await service.isAvailable();

      expect(available, isFalse);
      expect(client.installCalls, isEmpty);
    });

    test('installs configured model before generating text', () async {
      final client = _FakeLiteRtLmClient(hasActiveModel: false);
      final service = LiteRtLmService(
        client: client,
        config: const LiteRtLmConfig(
          modelUrl: 'https://example.com/gemma3-1b.task',
          modelKind: LiteRtLmModelKind.gemmaIt,
          backend: LiteRtLmBackend.gpu,
          maxTokens: 512,
        ),
      );

      final response = await service.generateText(
        'Extract receipt items',
        systemPrompt: 'Return JSON only.',
      );

      expect(response, 'ok');
      expect(client.installCalls, ['https://example.com/gemma3-1b.task']);
      expect(client.generatedPrompts.single, 'Extract receipt items');
      expect(client.generatedSystemPrompts.single, 'Return JSON only.');
      expect(client.backends.single, LiteRtLmBackend.gpu);
      expect(client.maxTokens.single, 512);
    });

    test('method channel client initializes from cached downloaded path', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      const channel = MethodChannel('test.litert_lm');
      final calls = <MethodCall>[];

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return switch (call.method) {
              'isAvailable' => call.arguments['modelPath'] ==
                  '/app/files/litert_lm_models/gemma.task',
              'installModel' => '/app/files/litert_lm_models/gemma.task',
              'initialize' => true,
              'generateContent' => 'done',
              _ => null,
            };
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });

      final client = MethodChannelLiteRtLmClient(
        config: const LiteRtLmConfig(modelUrl: 'https://example.com/gemma.task'),
        channel: channel,
      );
      final service = LiteRtLmService(
        client: client,
        config: const LiteRtLmConfig(modelUrl: 'https://example.com/gemma.task'),
      );

      final response = await service.generateText('hello');

      expect(response, 'done');
      expect(
        calls.where((call) => call.method == 'initialize').single.arguments,
        containsPair('modelPath', '/app/files/litert_lm_models/gemma.task'),
      );
    });
  });
}

class _FakeLiteRtLmClient implements LiteRtLmClient {
  _FakeLiteRtLmClient({required this.hasActiveModel});

  bool hasActiveModel;
  final installCalls = <String>[];
  final generatedPrompts = <String>[];
  final generatedSystemPrompts = <String?>[];
  final backends = <LiteRtLmBackend>[];
  final maxTokens = <int>[];

  @override
  Future<bool> activeModelExists() async => hasActiveModel;

  @override
  Future<String> generate({
    required String prompt,
    required LiteRtLmBackend backend,
    required int maxTokens,
    String? systemPrompt,
  }) async {
    generatedPrompts.add(prompt);
    generatedSystemPrompts.add(systemPrompt);
    backends.add(backend);
    this.maxTokens.add(maxTokens);
    return 'ok';
  }

  @override
  Future<void> initialize({String? huggingFaceToken}) async {}

  @override
  Future<void> installModel({
    required String url,
    required LiteRtLmModelKind modelKind,
    String? huggingFaceToken,
  }) async {
    installCalls.add(url);
    hasActiveModel = true;
  }
}
