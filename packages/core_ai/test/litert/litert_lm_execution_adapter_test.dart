import 'package:core_ai/core_ai.dart';
import 'package:core_native/core_native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('translates a v1 LiteRT plan without planner policy', () async {
    final client = _FakeClient();
    final adapter = LiteRtLmExecutionAdapter(client: client);
    final output = await adapter.generate(
      plan: _plan(),
      request: _request(),
      modelPath: '/models/gemma.litertlm',
      systemPrompt: 'Be concise.',
    );

    expect(output, 'ok');
    expect(client.initializedPath, '/models/gemma.litertlm');
    expect(client.initializedBackend, LiteRtLmBackend.gpu);
    expect(client.initializedMaxTokens, 32);
    expect(client.prompt, 'hello');
    expect(client.systemPrompt, 'Be concise.');
  });

  test('rejects plans for another runtime before touching the client', () {
    final client = _FakeClient();
    final adapter = LiteRtLmExecutionAdapter(client: client);
    final plan = _plan(runtime: RuntimeId.llamaCpp);

    expect(
      () => adapter.generate(
        plan: plan,
        request: _request(),
        modelPath: '/models/model',
      ),
      throwsArgumentError,
    );
    expect(client.initializedPath, isNull);
  });
}

InferenceRequest _request() => const InferenceRequest(
  capability: CapabilityId.chat,
  prompt: 'hello',
  modelId: null,
  priority: ExecutionPriority.interactive,
);

ExecutionPlan _plan({RuntimeId runtime = RuntimeId.liteRt}) => ExecutionPlan(
  ir: InferenceIr(
    runtime: runtime,
    accelerator: ComputeAccelerator.vulkan,
    modelId: 'gemma-chat',
    contextTokens: 256,
    outputTokens: 32,
    temperature: 0.2,
    topK: 40,
    topP: 0.9,
    priority: ExecutionPriority.interactive,
  ),
  batchSize: 1,
  thermalLimited: false,
  batterySaver: false,
);

class _FakeClient implements LiteRtLmClient {
  String? initializedPath;
  LiteRtLmBackend? initializedBackend;
  int? initializedMaxTokens;
  String? prompt;
  String? systemPrompt;

  @override
  Future<bool> activeModelExists({String? modelPath}) async => true;

  @override
  Future<String> generate({
    required String prompt,
    required LiteRtLmBackend backend,
    required int maxTokens,
    String? systemPrompt,
  }) async {
    this.prompt = prompt;
    this.systemPrompt = systemPrompt;
    return 'ok';
  }

  @override
  Future<void> initialize({
    String? huggingFaceToken,
    String? modelPath,
    LiteRtLmBackend? backend,
    int? maxTokens,
  }) async {
    initializedPath = modelPath;
    initializedBackend = backend;
    initializedMaxTokens = maxTokens;
  }

  @override
  Future<String?> installModel({
    required String url,
    required LiteRtLmModelKind modelKind,
    String? huggingFaceToken,
  }) async => null;
}
