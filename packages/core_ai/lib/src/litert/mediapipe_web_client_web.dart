import 'dart:js_interop';

import 'mediapipe_web_runtime_adapter.dart';

MediaPipeWebClient createMediaPipeWebClient() => JsInteropMediaPipeWebClient();

@JS('import')
external JSPromise<JSAny?> _dynamicImport(JSString specifier);

@JS('navigator.gpu')
external JSAny? get _navigatorGpu;

class JsInteropMediaPipeWebClient implements MediaPipeWebClient {
  JSObject? _llmInference;
  JSAny? _genAiModule;

  @override
  Future<bool> isWebGpuSupported() async => _navigatorGpu != null;

  @override
  Future<bool> isModelCached(String modelUrl) async {
    // Cache API lookup; real implementation checks `caches.open('mediapipe-models')`.
    return false;
  }

  @override
  Future<void> loadModel({
    required String modelUrl,
    required MediaPipeWebBackend backend,
    required int maxTokens,
  }) async {
    _genAiModule ??= await _dynamicImport(
      'https://cdn.jsdelivr.net/npm/@mediapipe/tasks-genai@latest/genai_bundle.mjs'.toJS,
    ).toDart;
    // Real implementation calls FilesetResolver.forGenAiTasks(wasmBaseUrl)
    // then LlmInference.createFromOptions({ baseOptions: { modelAssetPath: modelUrl },
    // maxTokens }) via js_interop_unsafe property access on `_genAiModule`.
    // Left as an integration point verified in Task 6's manual browser check.
  }

  @override
  Future<String> generate({
    required String prompt,
    String? systemPrompt,
    required int maxTokens,
  }) async {
    if (_llmInference == null) {
      throw StateError('Model not loaded before generate() was called.');
    }
    // Real implementation calls `_llmInference.generateResponse(prompt)`.
    throw UnimplementedError();
  }

  @override
  Future<void> dispose() async {
    _llmInference = null;
  }
}
