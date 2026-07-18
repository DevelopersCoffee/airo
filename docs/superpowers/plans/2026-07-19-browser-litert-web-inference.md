# Browser LiteRT (MediaPipe Web) Inference Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Airo's Mind chat work with a real local LLM when running as a Flutter web build, by adding a MediaPipe LLM Inference API (WASM/WebGPU) runtime adapter that plugs into the existing `LocalInferenceRuntimeAdapter` contract.

**Architecture:** `LiteRtLmService` (app layer) picks `MediaPipeWebRuntimeAdapter` when `kIsWeb` and the existing native `LiteRtLmRuntimeAdapter` otherwise. Both implement the same `core_ai` contract, so `AssistantRuntimeService` and the Mind chat / Model Library UI need no changes. The web adapter loads MediaPipe's `@mediapipe/tasks-genai` ESM bundle from a CDN via `dart:js_interop` dynamic `import()`, fetches the model's `.task` bundle and caches it in the browser Cache API, and drives `LlmInference.generateResponse`.

**Tech Stack:** Flutter web, `dart:js_interop` / `dart:js_interop_unsafe` (Dart 3.12 SDK-bundled, no new pubspec dependency needed), MediaPipe `@mediapipe/tasks-genai` (loaded at runtime from `https://cdn.jsdelivr.net`), browser Cache API.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-07-19-browser-litert-web-inference-design.md`
- Every new runtime file follows the existing `LocalInferenceRuntimeAdapter` contract in `packages/core_ai/lib/src/runtime/local_inference_runtime_adapter.dart` — do not change that interface.
- `LiteRtLmService` (`app/lib/core/services/litert_lm_service.dart`) is the only app-layer call site that changes. `AssistantRuntimeService`, `assistant_runtime_ids.dart` runtime IDs, and the Mind chat screen are not modified except for one new error message constant.
- No new pubspec dependency for JS interop — use SDK-bundled `dart:js_interop`.
- MediaPipe WASM/model assets load from CDN at runtime, never vendored into the repo.
- Qwen2.5-1.5B / SmolLM2 web catalog entries are gated behind a verification step (Task 7) — do not wire them into the picker until that step confirms an official `.task` bundle exists.
- Work happens in the git worktree at `.worktrees/browser-litert-web-inference` on branch `browser-litert-web-inference` — do not touch `main` directly.

---

### Task 1: `LocalRuntimeKind.mediaPipeWeb` enum value

**Files:**
- Modify: `packages/core_ai/lib/src/runtime/local_inference_runtime_adapter.dart:6`
- Test: `packages/core_ai/test/runtime/local_inference_runtime_adapter_test.dart` (new file)

**Interfaces:**
- Produces: `LocalRuntimeKind.mediaPipeWeb` (new enum member), consumed by Task 3's adapter and Task 4's service wiring.

- [ ] **Step 1: Write the failing test**

```dart
// packages/core_ai/test/runtime/local_inference_runtime_adapter_test.dart
import 'package:core_ai/core_ai.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('LocalRuntimeKind includes mediaPipeWeb for browser inference', () {
    expect(LocalRuntimeKind.values, contains(LocalRuntimeKind.mediaPipeWeb));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/core_ai && flutter test test/runtime/local_inference_runtime_adapter_test.dart`
Expected: FAIL — `LocalRuntimeKind.mediaPipeWeb` isn't defined (compile error).

- [ ] **Step 3: Add the enum value**

In `packages/core_ai/lib/src/runtime/local_inference_runtime_adapter.dart:6`, change:

```dart
enum LocalRuntimeKind { geminiNano, liteRtLm, gguf }
```

to:

```dart
enum LocalRuntimeKind { geminiNano, liteRtLm, gguf, mediaPipeWeb }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd packages/core_ai && flutter test test/runtime/local_inference_runtime_adapter_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add packages/core_ai/lib/src/runtime/local_inference_runtime_adapter.dart packages/core_ai/test/runtime/local_inference_runtime_adapter_test.dart
git commit -m "feat(core_ai): add mediaPipeWeb runtime kind"
```

---

### Task 2: `OfflineModelInfo` web-runtime fields + catalog entries

**Files:**
- Modify: `packages/core_ai/lib/src/models/offline_model_info.dart`
- Modify: `packages/core_ai/lib/src/registry/model_catalog.dart:16-91` (the `gemma-4-e2b-it-litertlm` and `gemma-4-e4b-it-litertlm` entries)
- Test: `packages/core_ai/test/registry/model_catalog_test.dart` (new file)

**Interfaces:**
- Produces: `OfflineModelInfo.supportsWebRuntime` (`bool`, default `false`), `OfflineModelInfo.webAssetUrl` (`String?`). Consumed by Task 3 (adapter reads `webAssetUrl`) and Task 4 (service checks `supportsWebRuntime` before offering a model on web).

- [ ] **Step 1: Write the failing test**

```dart
// packages/core_ai/test/registry/model_catalog_test.dart
import 'package:core_ai/core_ai.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ModelCatalog web runtime support', () {
    test('Gemma-4-E2B is flagged web-capable with a .task asset URL', () {
      final model = ModelCatalog.bundledModels.firstWhere(
        (m) => m.id == 'gemma-4-e2b-it-litertlm',
      );

      expect(model.supportsWebRuntime, isTrue);
      expect(model.webAssetUrl, isNotNull);
      expect(model.webAssetUrl, endsWith('.task'));
    });

    test('Gemma-4-E4B is flagged web-capable with a .task asset URL', () {
      final model = ModelCatalog.bundledModels.firstWhere(
        (m) => m.id == 'gemma-4-e4b-it-litertlm',
      );

      expect(model.supportsWebRuntime, isTrue);
      expect(model.webAssetUrl, isNotNull);
      expect(model.webAssetUrl, endsWith('.task'));
    });

    test('non-Gemma models default to web-unsupported', () {
      final model = ModelCatalog.bundledModels.firstWhere(
        (m) => m.id == 'mistral-7b-q4',
      );

      expect(model.supportsWebRuntime, isFalse);
      expect(model.webAssetUrl, isNull);
    });

    test('byWebRuntimeSupport returns only web-capable models', () {
      final webModels = ModelCatalog.webRuntimeSupported;

      expect(webModels, isNotEmpty);
      expect(webModels.every((m) => m.supportsWebRuntime), isTrue);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/core_ai && flutter test test/registry/model_catalog_test.dart`
Expected: FAIL — `supportsWebRuntime` getter doesn't exist on `OfflineModelInfo` (compile error).

- [ ] **Step 3: Add fields to `OfflineModelInfo`**

In `packages/core_ai/lib/src/models/offline_model_info.dart`, add to the constructor parameter list (after `recommendedMemoryBytes`):

```dart
    this.minMemoryBytes,
    this.recommendedMemoryBytes,
    this.supportsWebRuntime = false,
    this.webAssetUrl,
  });
```

Add the fields (after `recommendedMemoryBytes` field declaration):

```dart
  /// Recommended memory for optimal performance (bytes).
  final int? recommendedMemoryBytes;

  /// Whether this package has a confirmed MediaPipe LLM Inference API
  /// (`.task`) bundle for browser/WASM/WebGPU execution.
  final bool supportsWebRuntime;

  /// URL to the MediaPipe web `.task` bundle, distinct from [downloadUrl]
  /// (which points at the native `.litertlm`/GGUF artifact). Null unless
  /// [supportsWebRuntime] is true.
  final String? webAssetUrl;
```

Add to `copyWith` parameter list and body (after `recommendedMemoryBytes`):

```dart
    int? minMemoryBytes,
    int? recommendedMemoryBytes,
    bool? supportsWebRuntime,
    String? webAssetUrl,
  }) {
    return OfflineModelInfo(
      // ...existing fields...
      minMemoryBytes: minMemoryBytes ?? this.minMemoryBytes,
      recommendedMemoryBytes:
          recommendedMemoryBytes ?? this.recommendedMemoryBytes,
      supportsWebRuntime: supportsWebRuntime ?? this.supportsWebRuntime,
      webAssetUrl: webAssetUrl ?? this.webAssetUrl,
    );
  }
```

Add to `toJson`:

```dart
    'minMemoryBytes': minMemoryBytes,
    'recommendedMemoryBytes': recommendedMemoryBytes,
    'supportsWebRuntime': supportsWebRuntime,
    'webAssetUrl': webAssetUrl,
  };
```

Add to `fromJson`:

```dart
      minMemoryBytes: json['minMemoryBytes'] as int?,
      recommendedMemoryBytes: json['recommendedMemoryBytes'] as int?,
      supportsWebRuntime: json['supportsWebRuntime'] as bool? ?? false,
      webAssetUrl: json['webAssetUrl'] as String?,
    );
  }
```

- [ ] **Step 4: Populate the two Gemma catalog entries**

In `packages/core_ai/lib/src/registry/model_catalog.dart`, add to the `gemma-4-e2b-it-litertlm` entry (inside the `const OfflineModelInfo(...)` block starting at line 16, after `minMemoryBytes`/`recommendedMemoryBytes`):

```dart
      minMemoryBytes: 3500000000,
      recommendedMemoryBytes: 4500000000,
      supportsWebRuntime: true,
      webAssetUrl:
          'https://storage.googleapis.com/mediapipe-models/llm_inference/gemma-4-e2b-it/float16/latest/gemma-4-e2b-it.task',
    ),
```

And to the `gemma-4-e4b-it-litertlm` entry (starting at line 54):

```dart
      minMemoryBytes: 5500000000,
      recommendedMemoryBytes: 7000000000,
      supportsWebRuntime: true,
      webAssetUrl:
          'https://storage.googleapis.com/mediapipe-models/llm_inference/gemma-4-e4b-it/float16/latest/gemma-4-e4b-it.task',
    ),
```

(Both URLs point at MediaPipe's published model bucket for Gemma; Task 7 verifies these resolve before ship.)

- [ ] **Step 5: Add `ModelCatalog.webRuntimeSupported`**

In `packages/core_ai/lib/src/registry/model_catalog.dart`, add next to `officialModels`:

```dart
  /// Gets only models with a confirmed MediaPipe web (.task) bundle.
  static List<OfflineModelInfo> get webRuntimeSupported => bundledModels
      .where((m) => m.supportsWebRuntime)
      .toList();
```

- [ ] **Step 6: Run test to verify it passes**

Run: `cd packages/core_ai && flutter test test/registry/model_catalog_test.dart`
Expected: PASS

- [ ] **Step 7: Run full core_ai suite to check for regressions**

Run: `cd packages/core_ai && flutter test`
Expected: All existing tests still PASS (new fields are additive with defaults, `toJson`/`fromJson` round-trip unaffected for existing callers).

- [ ] **Step 8: Commit**

```bash
git add packages/core_ai/lib/src/models/offline_model_info.dart packages/core_ai/lib/src/registry/model_catalog.dart packages/core_ai/test/registry/model_catalog_test.dart
git commit -m "feat(core_ai): add web-runtime fields to OfflineModelInfo and flag Gemma catalog entries"
```

---

### Task 3: `MediaPipeWebRuntimeAdapter`

**Files:**
- Create: `packages/core_ai/lib/src/litert/mediapipe_web_runtime_adapter.dart`
- Test: `packages/core_ai/test/litert/mediapipe_web_runtime_adapter_test.dart`

**Interfaces:**
- Consumes: `LocalInferenceRuntimeAdapter`, `RuntimeCapabilities`, `RuntimeGenerationRequest`, `RuntimeBackend`, `LocalRuntimeKind.mediaPipeWeb` (Task 1), `OfflineModelInfo.supportsWebRuntime` / `.webAssetUrl` (Task 2), `LLMResponse`, `LLMConfig`, `TokenCounter.estimate` — all existing.
- Produces:
  - `abstract class MediaPipeWebClient` with methods:
    - `Future<bool> isWebGpuSupported()`
    - `Future<void> loadModel({required String modelUrl, required MediaPipeWebBackend backend, required int maxTokens})`
    - `Future<bool> isModelCached(String modelUrl)`
    - `Future<String> generate({required String prompt, String? systemPrompt, required int maxTokens})`
    - `Future<void> dispose()`
  - `enum MediaPipeWebBackend { wasm, webgpu }`
  - `class MediaPipeWebConfig` with `wasmBaseUrl` (default `'https://cdn.jsdelivr.net/npm/@mediapipe/tasks-genai@latest/wasm'`) and `maxTokens` (default `1024`).
  - `class MediaPipeWebRuntimeAdapter implements LocalInferenceRuntimeAdapter`, constructor `MediaPipeWebRuntimeAdapter({MediaPipeWebClient? client, MediaPipeWebConfig config = const MediaPipeWebConfig()})`. Consumed by Task 4.
  - `class JsInteropMediaPipeWebClient implements MediaPipeWebClient` — the real browser implementation, only ever instantiated when `kIsWeb` is true.

- [ ] **Step 1: Write the failing tests (fake client, no real JS interop)**

```dart
// packages/core_ai/test/litert/mediapipe_web_runtime_adapter_test.dart
import 'package:core_ai/core_ai.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeMediaPipeWebClient implements MediaPipeWebClient {
  _FakeMediaPipeWebClient({
    this.webGpuSupported = true,
    this.cached = false,
    this.response = 'Hello from the browser model.',
  });

  final bool webGpuSupported;
  bool cached;
  final String response;
  bool loadModelCalled = false;
  MediaPipeWebBackend? lastBackend;

  @override
  Future<bool> isWebGpuSupported() async => webGpuSupported;

  @override
  Future<bool> isModelCached(String modelUrl) async => cached;

  @override
  Future<void> loadModel({
    required String modelUrl,
    required MediaPipeWebBackend backend,
    required int maxTokens,
  }) async {
    loadModelCalled = true;
    lastBackend = backend;
    cached = true;
  }

  @override
  Future<String> generate({
    required String prompt,
    String? systemPrompt,
    required int maxTokens,
  }) async => response;

  @override
  Future<void> dispose() async {}
}

const _webCapableModel = OfflineModelInfo(
  id: 'gemma-4-e2b-it-litertlm',
  name: 'Gemma-4-E2B-it',
  family: ModelFamily.gemma,
  fileSizeBytes: 2583085056,
  provider: AIProvider.gemma,
  supportsWebRuntime: true,
  webAssetUrl: 'https://storage.googleapis.com/mediapipe-models/llm_inference/gemma-4-e2b-it/float16/latest/gemma-4-e2b-it.task',
);

const _webIncapableModel = OfflineModelInfo(
  id: 'mistral-7b-q4',
  name: 'Mistral 7B',
  family: ModelFamily.mistral,
  fileSizeBytes: 4100000000,
  provider: AIProvider.gguf,
);

void main() {
  group('MediaPipeWebRuntimeAdapter', () {
    test('runtimeKind is mediaPipeWeb', () {
      final adapter = MediaPipeWebRuntimeAdapter(
        client: _FakeMediaPipeWebClient(),
      );
      expect(adapter.runtimeKind, LocalRuntimeKind.mediaPipeWeb);
    });

    test('supportsModel is true only for catalog entries flagged web-capable', () async {
      final adapter = MediaPipeWebRuntimeAdapter(
        client: _FakeMediaPipeWebClient(),
      );

      expect(await adapter.supportsModel(_webCapableModel), isTrue);
      expect(await adapter.supportsModel(_webIncapableModel), isFalse);
    });

    test('capabilitiesForModel advertises webgpu backend when supported', () async {
      final adapter = MediaPipeWebRuntimeAdapter(
        client: _FakeMediaPipeWebClient(webGpuSupported: true),
      );

      // Prime the WebGPU check via prepareModel, then inspect capabilities.
      await adapter.prepareModel(model: _webCapableModel);
      final capabilities = adapter.capabilitiesForModel(_webCapableModel);

      expect(capabilities.supportedBackends, contains(RuntimeBackend.gpu));
      expect(capabilities.supportedBackends, contains(RuntimeBackend.cpu));
    });

    test('capabilitiesForModel omits gpu backend when WebGPU unsupported', () async {
      final adapter = MediaPipeWebRuntimeAdapter(
        client: _FakeMediaPipeWebClient(webGpuSupported: false),
      );

      await adapter.prepareModel(model: _webCapableModel);
      final capabilities = adapter.capabilitiesForModel(_webCapableModel);

      expect(capabilities.supportedBackends, isNot(contains(RuntimeBackend.gpu)));
      expect(capabilities.supportedBackends, contains(RuntimeBackend.cpu));
    });

    test('generateText loads the model then returns the client response', () async {
      final client = _FakeMediaPipeWebClient();
      final adapter = MediaPipeWebRuntimeAdapter(client: client);

      final text = await adapter.generateText(
        const RuntimeGenerationRequest(prompt: 'hi'),
        model: _webCapableModel,
      );

      expect(client.loadModelCalled, isTrue);
      expect(text, 'Hello from the browser model.');
    });

    test('generateText throws for a model with no web asset URL', () async {
      final adapter = MediaPipeWebRuntimeAdapter(
        client: _FakeMediaPipeWebClient(),
      );

      expect(
        () => adapter.generateText(
          const RuntimeGenerationRequest(prompt: 'hi'),
          model: _webIncapableModel,
        ),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('isAvailable is true for a client that can report readiness', () async {
      final adapter = MediaPipeWebRuntimeAdapter(
        client: _FakeMediaPipeWebClient(),
      );

      expect(await adapter.isAvailable(), isTrue);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/core_ai && flutter test test/litert/mediapipe_web_runtime_adapter_test.dart`
Expected: FAIL — `MediaPipeWebRuntimeAdapter`, `MediaPipeWebClient`, `MediaPipeWebBackend` are undefined (compile error).

- [ ] **Step 3: Implement `MediaPipeWebRuntimeAdapter` and the client abstraction**

```dart
// packages/core_ai/lib/src/litert/mediapipe_web_runtime_adapter.dart
import '../llm/llm_config.dart';
import '../llm/llm_response.dart';
import '../models/offline_model_info.dart';
import '../runtime/local_inference_runtime_adapter.dart';
import '../utils/token_counter.dart';
import 'mediapipe_web_client_stub.dart'
    if (dart.library.js_interop) 'mediapipe_web_client_web.dart';
import 'package:core_domain/core_domain.dart';

enum MediaPipeWebBackend { wasm, webgpu }

class MediaPipeWebConfig {
  const MediaPipeWebConfig({
    this.wasmBaseUrl =
        'https://cdn.jsdelivr.net/npm/@mediapipe/tasks-genai@latest/wasm',
    this.maxTokens = 1024,
  });

  final String wasmBaseUrl;
  final int maxTokens;
}

abstract class MediaPipeWebClient {
  Future<bool> isWebGpuSupported();

  Future<bool> isModelCached(String modelUrl);

  Future<void> loadModel({
    required String modelUrl,
    required MediaPipeWebBackend backend,
    required int maxTokens,
  });

  Future<String> generate({
    required String prompt,
    String? systemPrompt,
    required int maxTokens,
  });

  Future<void> dispose();
}

class MediaPipeWebRuntimeAdapter implements LocalInferenceRuntimeAdapter {
  MediaPipeWebRuntimeAdapter({
    MediaPipeWebClient? client,
    this.config = const MediaPipeWebConfig(),
  }) : _client = client ?? createMediaPipeWebClient();

  final MediaPipeWebClient _client;
  final MediaPipeWebConfig config;

  String? _loadedModelUrl;
  bool? _webGpuSupported;

  @override
  LocalRuntimeKind get runtimeKind => LocalRuntimeKind.mediaPipeWeb;

  @override
  LLMConfig get config_ => LLMConfig(
    provider: 'mediapipe-web',
    modelName: 'MediaPipe LLM Inference (Web)',
    maxOutputTokens: config.maxTokens,
  );

  @override
  LLMConfig get llmConfig => config_;

  @override
  int get maxContextLength => 4096;

  @override
  RuntimeCapabilities capabilitiesForModel(OfflineModelInfo model) {
    final backends = <RuntimeBackend>{RuntimeBackend.cpu};
    if (_webGpuSupported ?? false) {
      backends.add(RuntimeBackend.gpu);
    }
    return RuntimeCapabilities(
      supportedBackends: backends,
      supportsStreaming: false,
      supportsImages: false,
      supportsAudio: false,
      supportsToolCalling: false,
      supportsSystemPrompt: true,
      supportsSpeculativeDecoding: false,
    );
  }

  @override
  Future<void> prepareModel({OfflineModelInfo? model}) async {
    _webGpuSupported ??= await _client.isWebGpuSupported();
    if (model == null) return;
    await _ensureModelLoaded(model);
  }

  @override
  Future<Result<LLMResponse>> generate(String prompt) async {
    throw UnsupportedError(
      'MediaPipeWebRuntimeAdapter requires a model; use generateText with an OfflineModelInfo.',
    );
  }

  @override
  Stream<String> generateStream(String prompt) async* {
    throw UnsupportedError('MediaPipeWebRuntimeAdapter does not support streaming.');
  }

  @override
  Future<String?> generateText(
    RuntimeGenerationRequest request, {
    OfflineModelInfo? model,
  }) async {
    if (request.prompt.trim().isEmpty) return null;
    if (model == null || !model.supportsWebRuntime || model.webAssetUrl == null) {
      throw UnsupportedError(
        'MediaPipeWebRuntimeAdapter requires a model with supportsWebRuntime=true and a webAssetUrl.',
      );
    }
    if (request.requiresVision || request.requiresAudio || request.requiresToolCalling) {
      throw UnsupportedError(
        'MediaPipeWebRuntimeAdapter only supports plain text generation.',
      );
    }

    await _ensureModelLoaded(model);
    return _client.generate(
      prompt: request.prompt,
      systemPrompt: request.systemPrompt,
      maxTokens: config.maxTokens,
    );
  }

  @override
  Future<bool> isAvailable() async => true;

  @override
  int estimateTokens(String text) => TokenCounter.estimate(text);

  @override
  Future<void> dispose() => _client.dispose();

  @override
  Future<bool> supportsModel(OfflineModelInfo model) async =>
      model.supportsWebRuntime && model.webAssetUrl != null;

  Future<void> _ensureModelLoaded(OfflineModelInfo model) async {
    final assetUrl = model.webAssetUrl!;
    _webGpuSupported ??= await _client.isWebGpuSupported();
    if (_loadedModelUrl == assetUrl) return;

    final backend = (_webGpuSupported ?? false)
        ? MediaPipeWebBackend.webgpu
        : MediaPipeWebBackend.wasm;
    await _client.loadModel(
      modelUrl: assetUrl,
      backend: backend,
      maxTokens: config.maxTokens,
    );
    _loadedModelUrl = assetUrl;
  }
}
```

Note: `LocalInferenceRuntimeAdapter` (via `LLMClient`) requires a `config` getter of type `LLMConfig`. Check the exact getter name in `packages/core_ai/lib/src/llm/llm_client.dart` before finalizing — mirror `LiteRtLmRuntimeAdapter`'s existing `@override LLMConfig get config => ...` (see `litert_lm_runtime_adapter.dart:98-102`) instead of introducing `config_`/`llmConfig`. Use exactly:

```dart
  @override
  LLMConfig get config => LLMConfig(
    provider: 'mediapipe-web',
    modelName: 'MediaPipe LLM Inference (Web)',
    maxOutputTokens: config.maxTokens,
  );
```

This shadows the constructor's `config` field name — rename the constructor field to `runtimeConfig` (matching `LiteRtLmRuntimeAdapter`'s own `runtimeConfig` field name at `litert_lm_runtime_adapter.dart:88`) to avoid the collision:

```dart
  MediaPipeWebRuntimeAdapter({
    MediaPipeWebClient? client,
    this.runtimeConfig = const MediaPipeWebConfig(),
  }) : _client = client ?? createMediaPipeWebClient();

  final MediaPipeWebClient _client;
  final MediaPipeWebConfig runtimeConfig;
  // ...
  @override
  LLMConfig get config => LLMConfig(
    provider: 'mediapipe-web',
    modelName: 'MediaPipe LLM Inference (Web)',
    maxOutputTokens: runtimeConfig.maxTokens,
  );
```

Update every other `config.maxTokens` reference in the class body to `runtimeConfig.maxTokens`, and drop the stray `config_`/`llmConfig` getters shown above — they aren't part of the `LLMClient` contract.

Create the two conditional-import files:

```dart
// packages/core_ai/lib/src/litert/mediapipe_web_client_stub.dart
import 'mediapipe_web_runtime_adapter.dart';

MediaPipeWebClient createMediaPipeWebClient() {
  throw UnsupportedError(
    'MediaPipeWebClient is only available on the web platform.',
  );
}
```

```dart
// packages/core_ai/lib/src/litert/mediapipe_web_client_web.dart
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd packages/core_ai && flutter test test/litert/mediapipe_web_runtime_adapter_test.dart`
Expected: PASS — the unit tests only exercise `MediaPipeWebRuntimeAdapter` against the fake `_FakeMediaPipeWebClient`, never touching the real JS interop file, so they run on the VM test platform without a browser.

- [ ] **Step 5: Export from the package barrel**

In `packages/core_ai/lib/core_ai.dart`, add next to the existing litert export:

```dart
export 'src/litert/litert_lm_runtime_adapter.dart';
export 'src/litert/mediapipe_web_runtime_adapter.dart';
```

- [ ] **Step 6: Run full core_ai suite**

Run: `cd packages/core_ai && flutter test`
Expected: All PASS, including Task 1 and Task 2 tests.

- [ ] **Step 7: Commit**

```bash
git add packages/core_ai/lib/src/litert/mediapipe_web_runtime_adapter.dart packages/core_ai/lib/src/litert/mediapipe_web_client_stub.dart packages/core_ai/lib/src/litert/mediapipe_web_client_web.dart packages/core_ai/lib/core_ai.dart packages/core_ai/test/litert/mediapipe_web_runtime_adapter_test.dart
git commit -m "feat(core_ai): add MediaPipeWebRuntimeAdapter for browser LiteRT inference"
```

---

### Task 4: Wire `MediaPipeWebRuntimeAdapter` into `LiteRtLmService`

**Files:**
- Modify: `app/lib/core/services/litert_lm_service.dart`
- Test: `app/test/core/services/litert_lm_service_test.dart` (new file — none exists today per the earlier repo scan of `litert_lm_service_test.dart`/`litert_lm_service_warmup_test.dart`, which cover `LiteRtLmService` behavior already; add web-selection coverage alongside)

**Interfaces:**
- Consumes: `MediaPipeWebRuntimeAdapter` (Task 3), `LiteRtLmRuntimeAdapter` (existing), `kIsWeb` from `package:flutter/foundation.dart`.
- Produces: `LiteRtLmService` now exposes `bool get isUsingWebRuntime` for tests/diagnostics to assert which adapter is active.

- [ ] **Step 1: Write the failing test**

```dart
// app/test/core/services/litert_lm_service_test.dart
import 'package:core_ai/core_ai.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:airo/core/services/litert_lm_service.dart';

void main() {
  test('LiteRtLmService reports web runtime usage matches kIsWeb', () {
    final service = LiteRtLmService();
    expect(service.isUsingWebRuntime, kIsWeb);
  });

  test('LiteRtLmService can be constructed with an injected web adapter', () {
    final webAdapter = MediaPipeWebRuntimeAdapter(
      client: _NoopMediaPipeWebClient(),
    );
    final service = LiteRtLmService(webAdapter: webAdapter);

    expect(service.isUsingWebRuntime, isTrue);
  });
}

class _NoopMediaPipeWebClient implements MediaPipeWebClient {
  @override
  Future<bool> isWebGpuSupported() async => false;
  @override
  Future<bool> isModelCached(String modelUrl) async => false;
  @override
  Future<void> loadModel({
    required String modelUrl,
    required MediaPipeWebBackend backend,
    required int maxTokens,
  }) async {}
  @override
  Future<String> generate({
    required String prompt,
    String? systemPrompt,
    required int maxTokens,
  }) async => '';
  @override
  Future<void> dispose() async {}
}
```

Note: check `app/pubspec.yaml`'s package `name:` field (almost certainly `airo`) before finalizing the `import 'package:airo/core/services/litert_lm_service.dart'` line — match whatever the existing sibling tests (`app/test/core/services/litert_lm_service_test.dart` if present, or `litert_lm_service_warmup_test.dart`) already import.

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/core/services/litert_lm_service_test.dart`
Expected: FAIL — `isUsingWebRuntime` and the `webAdapter` named constructor parameter don't exist.

- [ ] **Step 3: Update `LiteRtLmService`**

```dart
// app/lib/core/services/litert_lm_service.dart
export 'package:core_ai/core_ai.dart'
    show
        LiteRtLmBackend,
        LiteRtLmClient,
        LiteRtLmConfig,
        LiteRtLmModelKind,
        LiteRtLmRuntimeAdapter,
        MediaPipeWebRuntimeAdapter,
        MethodChannelLiteRtLmClient;

import 'package:flutter/foundation.dart';
import 'package:core_ai/core_ai.dart';

/// Transitional app-facing shim around the framework-owned LiteRT-LM adapter.
///
/// Feature code should continue to inject/use this service until all call sites
/// move directly to the `core_ai` runtime contracts.
class LiteRtLmService {
  LiteRtLmService({
    LiteRtLmClient? client,
    this.config = const LiteRtLmConfig(),
    ModelDownloadService? downloadService,
    LiteRtLmRuntimeAdapter? adapter,
    MediaPipeWebRuntimeAdapter? webAdapter,
  }) : _isWeb = webAdapter != null || kIsWeb,
       _webAdapter = webAdapter ?? (kIsWeb ? MediaPipeWebRuntimeAdapter() : null),
       _nativeAdapter = (webAdapter != null || kIsWeb)
           ? null
           : (adapter ??
               LiteRtLmRuntimeAdapter(
                 client: client,
                 runtimeConfig: config,
                 downloadService: downloadService,
               ));

  final LiteRtLmConfig config;
  final bool _isWeb;
  final MediaPipeWebRuntimeAdapter? _webAdapter;
  final LiteRtLmRuntimeAdapter? _nativeAdapter;

  /// Whether this service is currently backed by the browser MediaPipe
  /// runtime instead of the native platform-channel runtime.
  bool get isUsingWebRuntime => _isWeb;

  Future<bool> isAvailable() =>
      _isWeb ? _webAdapter!.isAvailable() : _nativeAdapter!.isAvailable();

  Future<String?> generateText(String prompt, {String? systemPrompt}) {
    if (_isWeb) {
      throw UnsupportedError(
        'Browser runtime requires a model; call generateTextForModel instead.',
      );
    }
    return _nativeAdapter!.generateText(
      RuntimeGenerationRequest(prompt: prompt, systemPrompt: systemPrompt),
    );
  }

  Future<bool> warmupInstalledModel() => _isWeb
      ? Future.value(false)
      : _nativeAdapter!.warmupInstalledModel();

  Future<bool> warmupModel(OfflineModelInfo model) async {
    if (_isWeb) {
      if (!model.supportsWebRuntime) return false;
      await _webAdapter!.prepareModel(model: model);
      return true;
    }
    return _nativeAdapter!.warmupModel(model);
  }

  Future<String?> generateTextForModel(
    OfflineModelInfo model,
    String prompt, {
    String? systemPrompt,
  }) {
    final request = RuntimeGenerationRequest(
      prompt: prompt,
      systemPrompt: systemPrompt,
    );
    if (_isWeb) {
      return _webAdapter!.generateText(request, model: model);
    }
    return _nativeAdapter!.generateText(request, model: model);
  }

  Future<OfflineModelInfo> hydrateDownloadedModel(OfflineModelInfo model) {
    if (_isWeb) return Future.value(model);
    return _nativeAdapter!.hydrateDownloadedModel(model);
  }

  Future<String?> downloadedModelPath(String modelId) {
    if (_isWeb) return Future.value(null);
    return _nativeAdapter!.downloadedModelPath(modelId);
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/core/services/litert_lm_service_test.dart`
Expected: PASS

- [ ] **Step 5: Run existing LiteRT-LM app tests for regressions**

Run: `cd app && flutter test test/core/services/litert_lm_service_warmup_test.dart test/features/bill_split/receipt_litert_lm_extraction_service_test.dart`
Expected: All PASS. If any test constructs `LiteRtLmService` expecting the native adapter unconditionally, confirm it runs under the VM test platform where `kIsWeb` is `false` (it is, by default, for `flutter test` — only `flutter test -p chrome` sets it true), so `_nativeAdapter` is populated and behavior is unchanged.

- [ ] **Step 6: Commit**

```bash
git add app/lib/core/services/litert_lm_service.dart app/test/core/services/litert_lm_service_test.dart
git commit -m "feat(app): route LiteRtLmService to MediaPipeWebRuntimeAdapter on web"
```

---

### Task 5: Web-specific unavailable-runtime error message

**Files:**
- Modify: `app/lib/features/agent_chat/domain/models/assistant_runtime_ids.dart:12-13`
- Modify: `app/lib/features/agent_chat/data/services/assistant_runtime_service.dart` (the `litertGemmaAssistantModelId` case, `assistant_runtime_service.dart:382-493`)
- Test: `app/test/features/agent_chat/assistant_runtime_service_web_test.dart` (new file)

**Interfaces:**
- Consumes: `litertGemmaUnavailableMessage` (existing constant being supplemented, not replaced), `AssistantRuntimeUnavailableException` (existing).
- Produces: `litertWebRuntimeInitFailedMessage` (new `String` constant), thrown wrapped in the existing exception type — no new exception class.

- [ ] **Step 1: Write the failing test**

```dart
// app/test/features/agent_chat/assistant_runtime_service_web_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:airo/features/agent_chat/domain/models/assistant_runtime_ids.dart';

void main() {
  test('litertWebRuntimeInitFailedMessage explains the browser failure', () {
    expect(litertWebRuntimeInitFailedMessage, contains('browser'));
    expect(litertWebRuntimeInitFailedMessage, isNotEmpty);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/features/agent_chat/assistant_runtime_service_web_test.dart`
Expected: FAIL — `litertWebRuntimeInitFailedMessage` undefined.

- [ ] **Step 3: Add the constant**

In `app/lib/features/agent_chat/domain/models/assistant_runtime_ids.dart`, add after `litertGemmaUnavailableMessage` (line 13):

```dart
const String litertGemmaUnavailableMessage =
    'LiteRT-LM is not configured. Install a local model or set LITERT_LM_MODEL_PATH/LITERT_LM_MODEL_URL.';
const String litertWebRuntimeInitFailedMessage =
    'The browser local model runtime failed to start (WebGPU and WASM both unavailable). '
    'Try a different browser or use Gemini Cloud for this session.';
```

- [ ] **Step 4: Surface it in `AssistantRuntimeService`**

In `app/lib/features/agent_chat/data/services/assistant_runtime_service.dart`, the `litertGemmaAssistantModelId` branch (around line 388-410) calls `_liteRtLm.isAvailable()` to decide whether the runtime is blocked. On web, `LiteRtLmService.isAvailable()` now delegates to `MediaPipeWebRuntimeAdapter.isAvailable()`, which the plan's Task 3 implementation returns `true` unconditionally (WASM is always assumed loadable). Wrap the actual load failure at the point it would surface — in `generateText`'s `litertGemmaAssistantModelId` case (line 537-567), catch a load failure from `generateTextForModel` and rethrow with the web message when `kIsWeb`:

```dart
      case litertGemmaAssistantModelId:
        final package = await _resolveDownloadedLiteRtPackage(runtimeId);
        if (package != null) {
          final response = _nonEmptyOrUnavailable(
            runtimeId,
            await (_generateLiteRtModelTextOverride?.call(
                  package,
                  prompt,
                  systemPrompt: systemPrompt,
                ) ??
                _liteRtLm.generateTextForModel(
                  package,
                  prompt,
                  systemPrompt: systemPrompt,
                )),
            kIsWeb ? litertWebRuntimeInitFailedMessage : litertGemmaUnavailableMessage,
          );
          _emitResponseTrace(runtimeId, response, detail: package.id);
          return response;
        }
```

Add `import 'package:flutter/foundation.dart';` to the top of `assistant_runtime_service.dart` if not already present (it currently imports `flutter/foundation.dart` already, per line 4 — reuse the existing `kDebugMode` import line, just add `kIsWeb` to the same `show` clause if the import is a `show`-restricted one; otherwise no import change needed since `foundation.dart` is already imported unrestricted).

- [ ] **Step 5: Run test to verify it passes**

Run: `cd app && flutter test test/features/agent_chat/assistant_runtime_service_web_test.dart`
Expected: PASS

- [ ] **Step 6: Run full assistant runtime test suite for regressions**

Run: `cd app && flutter test test/features/agent_chat/`
Expected: All PASS — the native (`kIsWeb == false` under `flutter test`) path still uses `litertGemmaUnavailableMessage` exactly as before, since the ternary only changes behavior when `kIsWeb` is true.

- [ ] **Step 7: Commit**

```bash
git add app/lib/features/agent_chat/domain/models/assistant_runtime_ids.dart app/lib/features/agent_chat/data/services/assistant_runtime_service.dart app/test/features/agent_chat/assistant_runtime_service_web_test.dart
git commit -m "feat(app): add browser-specific unavailable-runtime message for Mind chat"
```

---

### Task 6: Manual browser verification (Mind chat end-to-end)

**Files:** none (verification task, no code changes)

- [ ] **Step 1: Run Airo web build in Chrome**

Run: `cd app && flutter run -d chrome --web-port=8765`

- [ ] **Step 2: Open Mind chat**

Navigate to `localhost:8765/#/mind`, select the LiteRT-LM / Gemma runtime candidate (not Gemini Cloud) from the model picker, and send a test prompt (e.g. "hi").

- [ ] **Step 3: Confirm the real interop gap**

Because `JsInteropMediaPipeWebClient.loadModel`/`generate` in Task 3 are stubbed with `UnimplementedError`/comments marking the real MediaPipe calls as an integration point, this manual run is expected to surface that gap directly in the browser console. Use this run to fill in the real `FilesetResolver.forGenAiTasks` / `LlmInference.createFromOptions` / `generateResponse` calls in `mediapipe_web_client_web.dart`, iterating in the browser devtools until a real prompt round-trips to a real Gemma response. This is the one part of the plan that cannot be fully specified without a browser to interactively inspect the `@mediapipe/tasks-genai` module shape.

- [ ] **Step 4: Re-run and confirm a real response renders in Mind chat**

Expected: the chat bubble shows generated text from the loaded Gemma model, not an "unavailable" error, and `chrome://inspect` / devtools console shows no uncaught JS exceptions from the MediaPipe load.

- [ ] **Step 5: Commit the filled-in interop implementation**

```bash
git add packages/core_ai/lib/src/litert/mediapipe_web_client_web.dart
git commit -m "fix(core_ai): complete MediaPipe web client JS interop against real browser behavior"
```

---

### Task 7: Verify Qwen2.5-1.5B / SmolLM2 official web bundle availability

**Files:**
- Modify: `packages/core_ai/lib/src/registry/model_catalog.dart` (only if verification succeeds)
- Modify: `packages/core_ai/test/registry/model_catalog_test.dart` (only if verification succeeds)

- [ ] **Step 1: Check for official MediaPipe `.task` bundles**

Check `https://huggingface.co/litert-community` and `https://storage.googleapis.com/mediapipe-models/llm_inference/` listings for `qwen2.5-1.5b` and `smollm2-1.7b` (or equivalent) entries with a `.task` artifact (not just `.litertlm`/GGUF).

- [ ] **Step 2a: If an official bundle exists**

Add a new `OfflineModelInfo` catalog entry (mirroring the structure at `model_catalog.dart:16-53`) with `supportsWebRuntime: true` and `webAssetUrl` set to the confirmed bundle URL, `provider: AIProvider.qwen` or the appropriate existing `AIProvider` value, `family: ModelFamily.qwen`. Add a corresponding test case to `model_catalog_test.dart` asserting `supportsWebRuntime` and the `.task` suffix, following the exact pattern used in Task 2's Step 1 tests.

- [ ] **Step 2b: If no official bundle exists**

Do not add a catalog entry. Leave a one-line code comment at the bottom of the `bundledModels` list in `model_catalog.dart` noting the gap so a future pass can revisit once `litert-community` publishes one:

```dart
    // Qwen2.5-1.5B / SmolLM2 web (.task) bundles: not yet published by
    // litert-community as of 2026-07-19. Re-check before adding a web
    // catalog entry for either model.
  ];
```

- [ ] **Step 3: Run full core_ai suite**

Run: `cd packages/core_ai && flutter test`
Expected: All PASS regardless of which branch (2a/2b) was taken.

- [ ] **Step 4: Commit**

```bash
git add packages/core_ai/lib/src/registry/model_catalog.dart packages/core_ai/test/registry/model_catalog_test.dart
git commit -m "chore(core_ai): resolve Qwen2.5/SmolLM2 web bundle verification"
```

---

## Self-Review Notes

- **Spec coverage:** `MediaPipeWebRuntimeAdapter` (Task 3) ✓, `LiteRtLmService` kIsWeb switch (Task 4) ✓, `ModelCatalog` web fields + Gemma entries (Task 2) ✓, default/manual model selection reusing existing Model Library UI (Task 4's `supportsWebRuntime` gate — no new UI needed, matches spec's "no new chat UI screens" non-goal) ✓, error handling via existing exception machinery + one new message (Task 5) ✓, testing mirroring existing patterns (Tasks 1-5 each include tests) ✓, Qwen/SmolLM2 gated verification (Task 7) ✓, worktree (created before this plan was written) ✓.
- **Real JS interop caveat:** Task 3's `JsInteropMediaPipeWebClient` ships with the MediaPipe-specific calls (`FilesetResolver`, `LlmInference.createFromOptions`, `generateResponse`) left as clearly marked integration points rather than guessed-at interop code, because getting `dart:js_interop` property/method access against a real third-party ESM module's exact shape right requires a browser to inspect against — guessing at it would violate the "no placeholders" rule in spirit even if syntactically it compiled. Task 6 is the deliberate, explicit step where that gap gets closed against the real running module, and it's called out as such rather than hidden inside a task that looks fully specified.
