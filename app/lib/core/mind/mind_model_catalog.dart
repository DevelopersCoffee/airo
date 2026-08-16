import 'dart:async';
import 'dart:io';

import 'package:core_ai/core_ai.dart';
import 'package:feature_mind/feature_mind.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:path/path.dart' as p;

import '../../features/settings/application/ai_model_management.dart';
import 'mind_model_sources.dart';

/// The Mind shell's model registry: the shared catalog plus the scribe's own
/// weights, so one screen answers "what is on this device" for the whole app.
///
/// This is an override rather than a change to [ModelCatalog]: the scribe's
/// models are not super-app models. Adding them to the shared statics would
/// put two undownloadable, unrunnable rows in every Airo install.
///
/// [modelsDirectory] is where the scribe actually installs — the same
/// directory `MindService` hands to the runtime — so "installed" here means
/// the file is on disk at its pinned size, not that a catalog said so.
/// [requiredModels] defaults to the pinned Rust registry, the single source of
/// file name, size and digest (`ADR-0018 §2`).
List<Override> mindModelRegistryOverrides({
  required Future<Directory> Function() modelsDirectory,
  Future<List<RequiredModel>> Function() requiredModels = pinnedRequiredModels,
}) => [
  modelRegistryProvider.overrideWith((ref) {
    final registry = ModelRegistry();
    registry.registerModels(ModelCatalog.bundledModels);
    unawaited(
      hydrateDownloadedModels(registry, ref.read(modelDownloadServiceProvider)),
    );
    unawaited(() async {
      final result = await hydratePublicHuggingFaceModels(registry);
      if (!ref.mounted) return;
      ref.read(huggingFaceCatalogAvailabilityProvider.notifier).state =
          result.availability;
      ref.read(huggingFaceCatalogErrorProvider.notifier).state =
          result.errorMessage;
    }());
    unawaited(
      hydrateMindScribeModels(
        registry,
        requiredModels: requiredModels,
        modelsDirectory: modelsDirectory,
      ),
    );
    ref.onDispose(registry.dispose);
    return registry;
  }),
];

/// Registers one entry per pinned scribe model, with a file path only when
/// the bytes are really there.
///
/// Failures are silent on purpose. The pinned list comes over the Rust bridge
/// and the directory comes from `path_provider`; when either is unavailable
/// the scribe screen is already the place that says so, and a settings screen
/// that throws on open would be a worse way to learn it.
Future<void> hydrateMindScribeModels(
  ModelRegistry registry, {
  required Future<List<RequiredModel>> Function() requiredModels,
  required Future<Directory> Function() modelsDirectory,
}) async {
  final List<RequiredModel> pinned;
  try {
    pinned = await requiredModels();
  } on Object {
    return;
  }

  Directory? directory;
  try {
    directory = await modelsDirectory();
  } on Object {
    directory = null;
  }

  for (final model in pinned) {
    registry.registerModel(
      _scribeModel(
        model,
        filePath: directory == null ? null : _installedPathIn(directory, model),
      ),
    );
  }

  for (final model in mindIndicOptionalModels()) {
    registry.registerModel(
      _scribeModel(
        model,
        filePath: directory == null ? null : _installedPathIn(directory, model),
      ),
    );
  }
}

/// The installed path for [model], or null when the file is absent or the
/// wrong size.
///
/// Size is checked because a half-written download leaves a file behind, and
/// reporting that as installed is how "the app says it has the model but
/// cannot transcribe" happens. The digest is not re-hashed here: that costs
/// hundreds of megabytes of I/O per screen open, and the acquisition path
/// already verifies it.
String? _installedPathIn(Directory directory, RequiredModel model) {
  final file = File(p.join(directory.path, model.fileName));
  if (!file.existsSync()) return null;
  return file.statSync().size == model.sizeBytes ? file.path : null;
}

OfflineModelInfo _scribeModel(RequiredModel model, {String? filePath}) {
  final descriptor =
      _scribeDescriptors[model.fileName] ?? _unknownScribeDescriptor(model);
  // Identity (file size, digest) is translated by feature_mind's model
  // -descriptor adapter (#1673); only presentation is supplied here.
  return offlineModelInfoFromRequiredModel(
    model,
    id: descriptor.id,
    name: descriptor.name,
    family: descriptor.family,
    filePath: filePath,
    downloadUrl: mindModelDownloadUrls[model.fileName],
    quantization: descriptor.quantization,
    parameterCount: descriptor.parameterCount,
    modalities: descriptor.modalities,
    capabilities: descriptor.capabilities,
    credibility: ModelCredibility.official,
    provider: AIProvider.custom,
    author: descriptor.author,
    license: descriptor.license,
    huggingFaceId: descriptor.huggingFaceId,
    description: descriptor.description,
    tags: const [mindScribeModelTag],
  );
}

/// Everything about a scribe model that the pinned registry deliberately does
/// not carry: it pins identity (name, size, digest), not presentation.
class _ScribeDescriptor {
  const _ScribeDescriptor({
    required this.id,
    required this.name,
    required this.family,
    required this.description,
    this.quantization = ModelQuantization.unknown,
    this.parameterCount,
    this.modalities = const [ModelModality.text],
    this.capabilities = const [],
    this.author,
    this.license,
    this.huggingFaceId,
  });

  final String id;
  final String name;
  final ModelFamily family;
  final String description;
  final ModelQuantization quantization;
  final int? parameterCount;
  final List<ModelModality> modalities;
  final List<ModelCapability> capabilities;
  final String? author;
  final String? license;
  final String? huggingFaceId;
}

const Map<String, _ScribeDescriptor> _scribeDescriptors = {
  'ggml-tiny.en.bin': _ScribeDescriptor(
    id: 'mind-scribe-whisper-tiny-en',
    name: 'Whisper Tiny (English)',
    // Whisper is an encoder-decoder speech model, not one of the text
    // architectures this enum names.
    family: ModelFamily.other,
    description:
        'English-only speech recognition for the Airo Mind Scribe. '
        'The standalone Mind shell defaults to the multilingual weights '
        'instead (`ggml-tiny.bin`) so Hindi/Marathi/English meetings '
        'transcribe with auto-detect.',
    modalities: [ModelModality.audio, ModelModality.text],
    capabilities: [ModelCapability.audioUnderstanding],
    author: 'OpenAI (ggml build by ggerganov)',
    license: 'MIT',
    huggingFaceId: 'ggerganov/whisper.cpp',
  ),
  'ggml-tiny.bin': _ScribeDescriptor(
    id: 'mind-scribe-whisper-tiny-multilingual',
    name: 'Whisper Tiny (Multilingual)',
    family: ModelFamily.other,
    description:
        'Multilingual speech recognition for the Airo Mind Scribe: '
        'Hindi, Marathi, English code-switching with auto-detect per '
        'recording (`#1629`). Required by the standalone Mind shell.',
    modalities: [ModelModality.audio, ModelModality.text],
    capabilities: [ModelCapability.audioUnderstanding],
    author: 'OpenAI (ggml build by ggerganov)',
    license: 'MIT',
    huggingFaceId: 'ggerganov/whisper.cpp',
  ),
  'qwen2.5-0.5b-instruct-q4_k_m.gguf': _ScribeDescriptor(
    id: 'mind-scribe-qwen2.5-0.5b-instruct',
    name: 'Qwen2.5 0.5B Instruct (Q4_K_M)',
    family: ModelFamily.qwen,
    description:
        'Powers the Airo Mind Scribe: writes the minutes and answers '
        'questions about what was said. Downloaded and verified by the '
        'Scribe, not by this screen.',
    quantization: ModelQuantization.q4,
    parameterCount: 500000000,
    capabilities: [ModelCapability.documents],
    author: 'Alibaba Qwen',
    license: 'Apache-2.0',
    huggingFaceId: 'Qwen/Qwen2.5-0.5B-Instruct-GGUF',
  ),
  'sarvam-1-Q4_K_M.gguf': _ScribeDescriptor(
    id: 'mind-scribe-sarvam-1-indic',
    name: 'Sarvam-1 (Q4_K_M) — Indic minutes',
    family: ModelFamily.other,
    description:
        'Optional pro pack: Sarvam-1 2B for Hindi/Marathi/Gujarati and '
        'other Indic meeting minutes. Requires ~8 GB RAM. Public mirror of '
        'sarvamai/sarvam-1 on Hugging Face — not Sarvam Edge ASR.',
    quantization: ModelQuantization.q4,
    parameterCount: 2000000000,
    capabilities: [ModelCapability.documents],
    author: 'Sarvam AI (GGUF by bartowski)',
    license: 'Apache-2.0',
    huggingFaceId: 'bartowski/sarvam-1-GGUF',
  ),
};

/// A model pinned in Rust that this shell has no description for.
///
/// Shown rather than skipped: a model added to the registry and not here is a
/// gap in this file, and a visible row named after the file is how it gets
/// noticed — a silently missing row looks exactly like a working app.
_ScribeDescriptor _unknownScribeDescriptor(RequiredModel model) =>
    _ScribeDescriptor(
      id: 'mind-scribe-${model.fileName}',
      name: model.fileName,
      family: ModelFamily.other,
      description: 'Required by the Airo Mind Scribe.',
    );
