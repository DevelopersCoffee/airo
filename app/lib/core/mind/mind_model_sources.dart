import 'package:core_ai/core_ai.dart';
import 'package:feature_mind/feature_mind.dart';
import 'package:flutter/foundation.dart';

/// Where Airo Mind's models are fetched from, and the provider that fetches
/// them.
///
/// # Why the URLs live in the app and not in `feature_mind`
///
/// `airo_mind_core::models` pins **identity** — file name, byte size, sha256
/// (`ADR-0018 §2`) — and that is the only thing the runtime is allowed to care
/// about: it proves which bytes are correct, never where to get them. Hosting
/// is distribution policy: it changes when Airo changes CDN, mirrors a model
/// for a region, or ships a build that bundles the weights instead. None of
/// those are reasons to touch a package that other shells embed, so the map
/// sits at the shell's composition root, which is the layer that already
/// decides which provider an app uses.
///
/// # Why these exact URLs
///
/// Each was downloaded and checked against the pinned registry before being
/// written down (#1554): the bytes at these addresses hash to exactly the
/// digests in `rust/airo_mind_core/src/models.rs`. A URL that has not been
/// verified against the pin does not belong here — a mismatch fails the
/// integrity check *after* half a gigabyte has been transferred, which is the
/// most expensive possible way to discover a typo.
///
/// `resolve/main` is a moving reference. It is the address these repositories
/// publish, and the pinned digest is what actually guards the bytes: if the
/// upstream file ever changes, the download fails verification instead of
/// installing something unpinned.
const Map<String, String> mindModelDownloadUrls = <String, String>{
  'ggml-tiny.en.bin':
      'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/'
      'ggml-tiny.en.bin',
  'ggml-tiny.bin':
      'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/'
      'ggml-tiny.bin',
  'ggml-small.bin':
      'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/'
      'ggml-small.bin',
  'ggml-small.en.bin':
      'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/'
      'ggml-small.en.bin',
  'qwen2.5-0.5b-instruct-q4_k_m.gguf':
      'https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/'
      'qwen2.5-0.5b-instruct-q4_k_m.gguf',
  'sarvam-1-Q4_K_M.gguf':
      'https://huggingface.co/bartowski/sarvam-1-GGUF/resolve/main/'
      'sarvam-1-Q4_K_M.gguf',
  'ecapa_tdnn_tiny_int8.onnx':
      'https://huggingface.co/vedk00/ecapa-voxceleb-speaker-embedding-onnx/resolve/main/'
      'model/ecapa-speaker-v1.onnx',
};

/// The URL for a pinned model, or null if this build has no source for it.
///
/// Null is a real answer, not a gap to paper over: the provider reports the
/// file as failed rather than silently skipping it, so a model added to the
/// Rust registry without a source here shows up as a visible failure instead
/// of an app that starts and cannot transcribe.
String? mindModelDownloadUrlFor(RequiredModel model) =>
    mindModelDownloadUrls[model.fileName];

/// Builds the [MindService] the standalone Airo Mind shell runs on, over
/// `core_ai`'s download pipeline.
///
/// The default [MindService] provider is the bundled-asset installer, and this
/// app does not bundle half a gigabyte of weights — without this wiring a
/// fresh install reported the models missing and offered nothing (#1554).
///
/// The download service is not handed back: `MindService.dispose` closes the
/// provider, which closes it. Nothing outside can see it once it is in there,
/// so nothing outside should be responsible for its subscription to the
/// platform download stream.
MindService buildMindDownloadService() {
  final useDownloadProvider =
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
  return MindService(
    // Hindi/Marathi/English code-switching in meetings needs multilingual
    // whisper weights and auto-detect per recording (`#1629`, `#1664`).
    // Settings can opt into English-only; [requiredModelsLookup] re-reads
    // that preference so the multilingual file is not forced on download.
    defaultSpeechLanguage: SpeechLanguage.multilingual,
    // ADR-0022 §1.2: durable log shared with assistant consent + runtime console.
    operationLog: sharedMindOperationLog(),
    meetingContextId: 'scribe',
    modelProvider: useDownloadProvider
        ? DownloadModelProvider(
            // Application support, not documents. Airo Mind keeps its models in the
            // app's support directory on purpose (`MindService.modelsDirectory`) —
            // on iOS the documents directory is user-visible in Files and backed up
            // to iCloud, which a 491 MB model has no business being. Staging the
            // download in documents would put it there anyway, along with the
            // install receipt left behind after the artifact is moved.
            downloadService: ModelDownloadService(
              storageLocation: ModelStorageLocation.applicationSupport,
            ),
            // Default weights plus multilingual when Settings is on Auto (mixed).
            // English opt-in (#1774) drops the multilingual row so first-run never
            // spends ~78 MB the user did not ask for.
            requiredModelsLookup: () async {
              final mode = await loadSpeechLanguageMode();
              return mindScribeRequiredModels(
                includeMultilingual: mode.includesMultilingualModel,
              );
            },
            downloadUrlFor: mindModelDownloadUrlFor,
          )
        : DesktopMindModelProvider(downloadUrlFor: mindModelDownloadUrlFor),
  );
}
