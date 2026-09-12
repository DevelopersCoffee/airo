import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:llama_flutter_android/llama_flutter_android.dart';

import 'completion_client.dart';
import 'completion_unavailable.dart';
import 'gguf_native_backend.dart';

/// GGUF [CompletionClient]. Prefers [native] when [GgufNativeBackend.isReady].
///
/// JNI (`llama_flutter_android`) has no grammar parameter — unconstrained
/// tokens only. GBNF is the native/FRB path.
class GgufCompletionClient implements CompletionClient {
  GgufCompletionClient({
    this.native,
    this.jni,
    this.jniIsLoaded,
    this.jniTimeout = const Duration(minutes: 2),
  });

  final GgufNativeBackend? native;
  final LlamaController? jni;
  final bool Function()? jniIsLoaded;
  final Duration jniTimeout;

  bool get _jniReady =>
      !kIsWeb && jni != null && (jniIsLoaded?.call() ?? false);

  @override
  bool get isAvailable => (native?.isReady ?? false) || _jniReady;

  @override
  Stream<String> generate({
    required String prompt,
    String? grammar,
    int maxTokens = 512,
    double temperature = 0.7,
    double topP = 0.9,
    int topK = 40,
  }) {
    final readyNative = native;
    if (readyNative != null && readyNative.isReady) {
      return readyNative.generate(
        prompt: prompt,
        maxTokens: maxTokens,
        grammar: grammar,
      );
    }
    if (_jniReady) {
      return _jniGenerate(
        prompt: prompt,
        maxTokens: maxTokens,
        temperature: temperature,
        topP: topP,
        topK: topK,
      );
    }
    final code = readyNative != null
        ? 'gguf_model_not_loaded'
        : 'gguf_backend_unavailable';
    return Stream<String>.error(CompletionUnavailable(code));
  }

  Stream<String> _jniGenerate({
    required String prompt,
    required int maxTokens,
    required double temperature,
    required double topP,
    required int topK,
  }) async* {
    final controller = jni!;
    try {
      await for (final token
          in controller
              .generate(
                prompt: prompt,
                maxTokens: maxTokens,
                temperature: temperature,
                topP: topP,
                topK: topK,
              )
              .timeout(jniTimeout)) {
        yield token;
      }
    } on TimeoutException {
      await stop();
      throw TimeoutException('GGUF generation timed out.');
    }
  }

  @override
  Future<void> stop() async {
    if (native?.isReady ?? false) {
      await native!.stop();
      return;
    }
    if (jni?.isGenerating ?? false) await jni!.stop();
  }
}
