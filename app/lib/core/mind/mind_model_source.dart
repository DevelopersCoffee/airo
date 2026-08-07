import 'package:core_ai/core_ai.dart' show ModelDownloadService;
import 'package:feature_mind/feature_mind.dart';

/// Where the Mind shell's models come from: hosting is a Dart-side decision
/// (`ADR-0018 §1`), and this is where the shell makes it.
///
/// `airo_mind_core::models` pins each model's file name, size and digest —
/// [MindService] reads that registry through [ModelProvider.requiredModels]
/// and never invents an entry — but pins no URL. The three lines below are the
/// entire policy: which host serves the two files
/// `app/tool/fetch_mind_models.sh` already downloads from for local dev.
///
/// A file it does not recognise fails closed (`null`) rather than guessing a
/// URL, so [DownloadModelProvider.acquire] reports it in `failedFileNames`
/// instead of enqueueing a request that can never resolve.
String? mindModelDownloadUrl(RequiredModel model) {
  const hosts = <String, String>{
    'ggml-tiny.en.bin':
        'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/'
        'ggml-tiny.en.bin',
    'qwen2.5-0.5b-instruct-q4_k_m.gguf':
        'https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/'
        'qwen2.5-0.5b-instruct-q4_k_m.gguf',
  };
  return hosts[model.fileName];
}

/// Builds the [ModelProvider] the Mind shell installs by default: Airo's
/// existing download pipeline (`core_ai.ModelDownloadService`), not the
/// bundled asset. Neither app ships model weights in the APK any more
/// (`docs/superpowers/specs/2026-08-07-airo-mind-abstraction-layer.md`).
///
/// [requiredModelsLookup] is `feature_mind`'s own registry accessor —
/// supplied here rather than imported by `DownloadModelProvider` itself,
/// because a provider must not know the generated bridge exists. `MindService`
/// exposes it only indirectly (through whichever provider it holds), so this
/// function reaches it the same way `MindService`'s bundled default always
/// has: via `ModelInstaller`, which already does this translation.
ModelProvider buildMindModelProvider() {
  const bundled = ModelInstaller();
  return DownloadModelProvider(
    downloadService: ModelDownloadService(),
    requiredModelsLookup: bundled.requiredModels,
    downloadUrlFor: mindModelDownloadUrl,
  );
}
