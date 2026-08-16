import 'package:core_ai/core_ai.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('downloaded LiteRT package is not runnable on macOS', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    final model = OfflineModelInfo(
      id: 'gemma-4-e2b-it-litertlm',
      name: 'Gemma-4-E2B-it',
      family: ModelFamily.gemma,
      fileSizeBytes: 2_000_000_000,
      filePath: '/models/gemma-4-e2b-it.litertlm',
      provider: AIProvider.gemma,
      runtime: InferenceRuntime.litertLm,
      platformSupport: PlatformSupport.androidOnly(),
    );

    final readiness = ModelReadinessService.evaluate(
      model,
      nativeGgufAvailable: true,
      liteRtNativeAvailable: true,
      webMediaPipeAvailable: false,
    );

    expect(readiness.isRunnable, isFalse);
    expect(readiness.canPrepare, isFalse);
    expect(readiness.headline, contains('macOS'));
  });

  test('downloaded GGUF is runnable when llama.cpp backend is available', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    final model = OfflineModelInfo(
      id: 'qwen2-1.5b-q4',
      name: 'Qwen2 1.5B',
      family: ModelFamily.qwen,
      fileSizeBytes: 1_100_000_000,
      filePath: '/models/qwen2-1.5b-q4.gguf',
      provider: AIProvider.gguf,
    );

    final readiness = ModelReadinessService.evaluate(
      model,
      nativeGgufAvailable: true,
      liteRtNativeAvailable: false,
      webMediaPipeAvailable: false,
    );

    expect(readiness.isRunnable, isTrue);
    expect(readiness.canPrepare, isTrue);
  });

  test('downloaded GGUF is blocked when llama.cpp backend is missing', () {
    final model = OfflineModelInfo(
      id: 'qwen2-1.5b-q4',
      name: 'Qwen2 1.5B',
      family: ModelFamily.qwen,
      fileSizeBytes: 1_100_000_000,
      filePath: '/models/qwen2-1.5b-q4.gguf',
      provider: AIProvider.gguf,
    );

    final readiness = ModelReadinessService.evaluate(
      model,
      nativeGgufAvailable: false,
      liteRtNativeAvailable: false,
      webMediaPipeAvailable: false,
    );

    expect(readiness.isRunnable, isFalse);
    expect(readiness.detail, contains('llama.cpp'));
  });
}
