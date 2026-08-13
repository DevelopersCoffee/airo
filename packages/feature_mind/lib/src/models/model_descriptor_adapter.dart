/// The single boundary adapter between the three model-descriptor
/// vocabularies feature_mind touches (#1673):
///
/// 1. The FRB-**generated** `whisper.api.setup.RequiredModel`/
///    `InstalledModel` (`BigInt` wire types) — never edited, never spoken
///    outside this file and `rust_mind_runtime.dart`.
/// 2. The **hand-written** [RequiredModel]/[InstalledModel] in
///    `model_provider.dart` (`int` sizes) — what every [ModelProvider]
///    speaks. Deliberately bridge-ignorant; see the doc comment there.
/// 3. **core_ai**'s [OfflineModelInfo] — the ~30-field catalog entry a shell
///    (`app/lib/core/mind/mind_model_catalog.dart`) shows in a model picker.
///
/// The `int`/`BigInt` split between (1) and (2) is deliberate bridge
/// isolation (`ADR-0018`), not something to merge away — only the numeric
/// cast crosses here. Every other file that used to reconcile these shapes
/// field-by-field should call a function in this file instead of
/// re-deriving the mapping.
library;

import 'package:core_ai/core_ai.dart'
    show
        AIProvider,
        ModelCapability,
        ModelCredibility,
        ModelFamily,
        ModelModality,
        ModelQuantization,
        OfflineModelInfo;

import '../whisper/api/setup.dart' as rust;
import 'model_provider.dart';

/// Bridge → hand-written [RequiredModel]. Only the `BigInt` → `int` cast
/// changes; file name and digest pass through unchanged.
RequiredModel requiredModelFromBridge(rust.RequiredModel model) =>
    RequiredModel(
      fileName: model.fileName,
      sizeBytes: model.sizeBytes.toInt(),
      sha256: model.sha256,
    );

/// Bridge → hand-written [InstalledModel]. Structurally identical today;
/// kept as an explicit function rather than a blind field copy so a future
/// divergence between the generated and hand-written shapes fails at this
/// one call site instead of at every provider that calls
/// `rust.verifyInstalledModels`.
InstalledModel installedModelFromBridge(rust.InstalledModel model) =>
    InstalledModel(
      fileName: model.fileName,
      present: model.present,
      verified: model.verified,
      detail: model.detail,
    );

/// The pinned registry from `airo_mind_core::models`, translated across the
/// bridge into the shape a [ModelProvider] speaks.
///
/// One function rather than one per provider: `ADR-0018 §2` puts identity —
/// file name, size, digest — in Rust source and nowhere else, so every Dart
/// caller that needs it (`ModelInstaller`, a shell composing
/// `DownloadModelProvider`) should be reading the same translation.
///
/// Where the bytes are *hosted* is deliberately not here: the registry
/// proves which bytes are correct, not where to find them (`ADR-0018 §1` —
/// the runtime never acquires models). That is the shell's `downloadUrlFor`.
Future<List<RequiredModel>> pinnedRequiredModels() async => [
  for (final model in await rust.requiredModels())
    requiredModelFromBridge(model),
];

/// Full verification of what is installed, translated into the shape a
/// [ModelProvider] speaks.
///
/// Hashes every file, so it is **not** on the launch path — half a gigabyte
/// is about a second. `ModelProvider.isInstalled` does the cheap size check
/// on every launch instead.
Future<List<InstalledModel>> verifyInstalledModels({
  required String modelsDir,
}) async => [
  for (final status in await rust.verifyInstalledModels(modelsDir: modelsDir))
    installedModelFromBridge(status),
];

/// [RequiredModel] → [OfflineModelInfo]: maps only the identity fields the
/// two shapes actually share — file size and digest. Everything
/// presentation (name, family, quantization, capabilities, licensing…) is
/// supplied by the caller, not derived here: the pinned registry proves
/// which bytes are correct, not how to describe them to a user
/// (`ADR-0018 §1`). A shell's catalog (e.g.
/// `mind_model_catalog.dart`'s scribe descriptors) owns that presentation
/// data and passes it through.
OfflineModelInfo offlineModelInfoFromRequiredModel(
  RequiredModel model, {
  required String id,
  required String name,
  required ModelFamily family,
  String? description,
  String? filePath,
  String? downloadUrl,
  ModelQuantization quantization = ModelQuantization.unknown,
  int? parameterCount,
  List<ModelModality> modalities = const [ModelModality.text],
  List<ModelCapability> capabilities = const [],
  ModelCredibility credibility = ModelCredibility.community,
  AIProvider provider = AIProvider.custom,
  String? author,
  String? license,
  String? huggingFaceId,
  List<String> tags = const [],
}) => OfflineModelInfo(
  id: id,
  name: name,
  family: family,
  fileSizeBytes: model.sizeBytes,
  filePath: filePath,
  downloadUrl: downloadUrl,
  sha256: model.sha256,
  quantization: quantization,
  parameterCount: parameterCount,
  modalities: modalities,
  capabilities: capabilities,
  credibility: credibility,
  provider: provider,
  author: author,
  license: license,
  huggingFaceId: huggingFaceId,
  description: description,
  tags: tags,
);
