import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'mediapipe_web_runtime_adapter.dart';

MediaPipeWebClient createMediaPipeWebClient() => JsInteropMediaPipeWebClient();

const _genAiModuleUrl =
    'https://cdn.jsdelivr.net/npm/@mediapipe/tasks-genai@latest/genai_bundle.mjs';
const _wasmBaseUrl =
    'https://cdn.jsdelivr.net/npm/@mediapipe/tasks-genai@latest/wasm';

// `import()` is JS syntax, not a property of `globalThis`, so it can't be
// declared as a normal `@JS('import') external` binding. The `Function`
// global IS a real property, and per the JS spec calling it without `new`
// still constructs a function — this is the standard workaround for
// invoking dynamic `import()` from generated interop code.
@JS('Function')
external JSFunction _functionConstructor(JSString paramName, JSString body);

@JS('navigator.gpu')
external JSAny? get _navigatorGpu;

@JS('console.log')
external void _consoleLog(JSAny? message);

@JS('JSON.stringify')
external JSString? _jsonStringify(JSAny? value);

String _extractText(JSAny? value) {
  if (value == null) return '';
  if (value.isA<JSString>()) {
    return (value as JSString).toDart;
  }
  _consoleLog('[MediaPipeWebClient] generateResponse returned a non-string value:'.toJS);
  _consoleLog(value);
  final stringified = _jsonStringify(value);
  return stringified?.toDart ?? value.toString();
}

Future<JSAny?> _dynamicImport(String specifier) async {
  final importer = _functionConstructor(
    'specifier'.toJS,
    'return import(specifier)'.toJS,
  );
  final result = importer.callAsFunction(null, specifier.toJS);
  final promise = result! as JSPromise<JSAny?>;
  return promise.toDart;
}

class JsInteropMediaPipeWebClient implements MediaPipeWebClient {
  JSObject? _genAiModule;
  JSObject? _llmInference;

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
    void Function(String stage)? onProgress,
  }) async {
    onProgress?.call('Loading inference engine…');
    final module = _genAiModule ??= await _dynamicImport(_genAiModuleUrl) as JSObject?;
    if (module == null) {
      throw StateError('Failed to load the MediaPipe GenAI module from $_genAiModuleUrl.');
    }

    onProgress?.call('Preparing WASM runtime…');
    final filesetResolverClass = module.getProperty('FilesetResolver'.toJS) as JSObject;
    final filesetPromise = filesetResolverClass.callMethod(
      'forGenAiTasks'.toJS,
      _wasmBaseUrl.toJS,
    ) as JSPromise<JSAny?>;
    final fileset = await filesetPromise.toDart;

    onProgress?.call('Downloading model (this can take a while on first load)…');
    final baseOptions = JSObject()..setProperty('modelAssetPath'.toJS, modelUrl.toJS);
    final options = JSObject()
      ..setProperty('baseOptions'.toJS, baseOptions)
      ..setProperty('maxTokens'.toJS, maxTokens.toJS);

    final llmInferenceClass = module.getProperty('LlmInference'.toJS) as JSObject;
    final llmPromise = llmInferenceClass.callMethod(
      'createFromOptions'.toJS,
      fileset,
      options,
    ) as JSPromise<JSAny?>;
    _llmInference = await llmPromise.toDart as JSObject?;
    onProgress?.call('Model ready.');
  }

  @override
  Future<String> generate({
    required String prompt,
    String? systemPrompt,
    required int maxTokens,
  }) async {
    final inference = _llmInference;
    if (inference == null) {
      throw StateError('Model not loaded before generate() was called.');
    }

    final fullPrompt = (systemPrompt == null || systemPrompt.isEmpty)
        ? prompt
        : '$systemPrompt\n\n$prompt';

    _consoleLog('[MediaPipeWebClient] calling generateResponse with prompt:'.toJS);
    _consoleLog(fullPrompt.toJS);
    final result = inference.callMethod('generateResponse'.toJS, fullPrompt.toJS);
    _consoleLog('[MediaPipeWebClient] raw generateResponse() call result:'.toJS);
    _consoleLog(result);
    if (result != null && result.isA<JSPromise>()) {
      final resolved = await (result as JSPromise<JSAny?>).toDart;
      _consoleLog('[MediaPipeWebClient] resolved generateResponse() promise value:'.toJS);
      _consoleLog(resolved);
      return _extractText(resolved);
    }
    return _extractText(result);
  }

  @override
  Future<void> dispose() async {
    _llmInference = null;
  }
}
